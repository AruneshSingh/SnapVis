//
//  ScreencaptureViewModel.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 24/01/25.
//

import Foundation
import SwiftUI
import KeyboardShortcuts
import Vision
import AppKit
import PostHog

// MARK: - Banner View
// ... existing code ...

// MARK: - Banner Manager
// ... existing code ...

class ScreencaptureViewModel: ObservableObject {
    
    enum ScreenshotTypes {
        case area
        
        var processArguments: [String] {
            switch self {
            case .area:
                return ["-cs"]
            }
        }
    }
    
    @Published var images = [NSImage]()
    @Published var lastRecognizedText: String = ""
    @Published var isFormatting: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var promptedScreenshotImage: NSImage?
    
    // State for the prompted screenshot flow
    @Published var showingPromptInputWindow: Bool = false
    @Published var showingChatResponseWindow: Bool = false // We'll use this later
    @Published var userPrompt: String = ""
    @Published var apiResponse: String? = nil
    @Published var isLoadingResponse: Bool = false
    
    private let geminiAPIClient = GeminiAPIClient()
    
    init() {
        KeyboardShortcuts.onKeyUp(for: .screenshotCapture) { [self] in
            self.takeScreenShot(for: .area, processImmediately: true)
        }
        // Add listener for the new shortcut
        KeyboardShortcuts.onKeyUp(for: .promptedScreenshotCapture) { [self] in
             self.startPromptedScreenshotFlow()
        }
    }
    
    func takeScreenShot(for type: ScreenshotTypes, processImmediately: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = type.processArguments
        
        do {
            try task.run()
            task.waitUntilExit()
            print("[takeScreenShot] Process finished. processImmediately flag: \(processImmediately)")
            // Only get image from pasteboard if requested
            if processImmediately {
                print("[takeScreenShot] Calling getImageFromPasteboard() because processImmediately is true.")
                getImageFromPasteboard()
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    private func getImageFromPasteboard() {
        print("[getImageFromPasteboard] Function called.")
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else { 
            print("[getImageFromPasteboard] Cannot read image types from pasteboard.")
            return 
        }
        
        guard let image = NSImage(pasteboard: NSPasteboard.general) else { return }
        
        self.images.append(image)
        
        PostHogSDK.shared.capture("Screenshot taken")
        
        // Show the processing banner
        BannerWindowController.shared.showBanner(message: "Processing with Gemini AI...", isLoading: true)
        
        // Use Gemini API by default for OCR
        processImageWithGemini(image)
    }
    
    private func processImageWithGemini(_ image: NSImage) {
        DispatchQueue.main.async {
            self.isFormatting = true
            self.errorMessage = ""
            self.showError = false
        }
        
        // Simple prompt for basic text extraction
        let prompt = "Please analyze this image and extract all the text. " +
                    "Format the text properly maintaining the structure, layout, indentation and heading heirarchy." +
                    "For code snippets, preserve the syntax highlighting and indentation, and remove the line numbers and other UI elements, only keep the actual code." +
                    "For diagrams, convert them to mermaid format and give the mermaid code only." +
                    "For tables, maintain the tabular format. " +
                    "Do not give any explanation or any extra information. Only the required content."
        
        geminiAPIClient.formatImageText(image: image, prompt: prompt) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isFormatting = false
                
                switch result {
                case .success(let extractedText):
                    self.lastRecognizedText = extractedText
                    self.copyToClipboard(text: extractedText)
                    
                    // Update banner to show success
                    print("Updating banner with success: Copied to clipboard")
                    BannerWindowController.shared.updateBanner(message: "Copied to clipboard", isLoading: false)
                    
                case .failure(let error):
                    print("Gemini API error, falling back to Vision OCR: \(error.localizedDescription)")
                    
                    // Check if it's a network-related error to decide whether to show the error
                    let isNetworkError = self.isNetworkError(error)
                    
                    if isNetworkError {
                        // For network errors, fall back to Vision OCR
                        BannerWindowController.shared.updateBanner(message: "Network error, falling back to local OCR...", isLoading: true)
                        if let lastImage = self.images.last {
                            self.performOCR(on: lastImage)
                        }
                    } else {
                        // For other errors, display the error
                        self.displayError(error)
                        BannerWindowController.shared.updateBanner(message: "Error processing image", isLoading: false)
                    }
                }
            }
        }
    }
    
    // Helper to check if an error is network-related
    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, 
                 .networkConnectionLost,
                 .cannotFindHost, 
                 .cannotConnectToHost, 
                 .timedOut, 
                 .dnsLookupFailed,
                 .internationalRoamingOff:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    // Vision OCR as fallback
    private func performOCR(on image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to create CGImage from NSImage")
            BannerWindowController.shared.updateBanner(message: "Failed to process image", isLoading: false)
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error recognizing text: \(error)")
                BannerWindowController.shared.updateBanner(message: "Error recognizing text", isLoading: false)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.lastRecognizedText = recognizedText
                self.copyToClipboard(text: recognizedText)
                BannerWindowController.shared.updateBanner(message: "Copied to clipboard", isLoading: false)
            }
        }
        
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing OCR request: \(error)")
            BannerWindowController.shared.updateBanner(message: "Failed to perform OCR", isLoading: false)
        }
    }
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Text copied to clipboard: \(text)")
    }
    
    private func displayError(_ error: Error) {
        var message = "Error formatting text: "
        
        switch error {
        case let apiError as GeminiAPIClient.APIError:
            switch apiError {
            case .imageConversionFailed:
                message += "Failed to convert image."
            case .noData:
                message += "No data received from API."
            case .parseError:
                message += "Failed to parse API response."
            case .invalidURL:
                message += "Invalid API URL."
            case .apiError(let details):
                message += details
            }
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet:
                message += "No internet connection."
            case .cannotFindHost:
                message += "Cannot find API server. Check your internet connection."
            case .timedOut:
                message += "Request timed out. Try again."
            default:
                message += "Network error: \(urlError.localizedDescription)"
            }
        default:
            message += error.localizedDescription
        }
        
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
    
    // Add new function for the prompted screenshot flow
    func startPromptedScreenshotFlow() {
        print("Prompted Screenshot Shortcut Pressed!")
        // 1. Trigger area screenshot capture (uses pasteboard, DO NOT process immediately)
        takeScreenShot(for: .area, processImmediately: false)
        
        // 2. Get image from pasteboard (similar to getImageFromPasteboard)
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else { 
            print("Error: Could not read image from pasteboard for prompted flow.")
            return 
        }
        guard let image = NSImage(pasteboard: NSPasteboard.general) else { 
            print("Error: Failed to get image from pasteboard for prompted flow.")
            return 
        }
        
        // 3. Store the image
        self.promptedScreenshotImage = image
        print("Image captured for prompting. Ready for prompt UI.")

        // TODO: Implement prompt UI display
        // Show the prompt input window
        DispatchQueue.main.async {
            self.showingPromptInputWindow = true
        }

        // TODO: Clear pasteboard after getting the image?
    }
    
    // Function to handle prompt submission and initiate API call
    func submitPromptForProcessing(prompt: String) {
        guard let imageToProcess = promptedScreenshotImage else {
            print("Error: No image available for processing.")
            // Optionally show an error to the user (e.g., set errorMessage)
            return
        }
        
        // Store the prompt
        self.userPrompt = prompt
        
        // Set loading state and reset previous response
        DispatchQueue.main.async {
            self.isLoadingResponse = true
            self.apiResponse = nil
            // Show the chat window (we'll add this window definition next)
            self.showingChatResponseWindow = true 
        }
        
        print("Submitting prompt: \(prompt) with image.")
        
        // Call Gemini API
        geminiAPIClient.formatImageText(image: imageToProcess, prompt: prompt) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingResponse = false
                switch result {
                case .success(let responseText):
                    self.apiResponse = responseText
                    print("Gemini API success for prompted screenshot.")
                    // Maybe clear the promptedScreenshotImage here if no longer needed?
                    // self.promptedScreenshotImage = nil 
                case .failure(let error):
                    // Handle API error (e.g., display in the chat window or separate error UI)
                    self.apiResponse = "Error: \(error.localizedDescription)" // Display error in response area for now
                    print("Gemini API error for prompted screenshot: \(error.localizedDescription)")
                    self.displayError(error) // Optionally use existing error display logic
                }
            }
        }
    }
}
