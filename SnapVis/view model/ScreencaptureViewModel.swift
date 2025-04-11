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
    
    private let geminiAPIClient = GeminiAPIClient()
    
    init() {
        KeyboardShortcuts.onKeyUp(for: .screenshotCapture) { [self] in
            self.takeScreenShot(for: .area)
        }
    }
    
    func takeScreenShot(for type: ScreenshotTypes) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = type.processArguments
        
        do {
            try task.run()
            task.waitUntilExit()
            getImageFromPasteboard()
        } catch {
            print("Error: \(error)")
        }
    }
    
    private func getImageFromPasteboard() {
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else { return }
        
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
}
