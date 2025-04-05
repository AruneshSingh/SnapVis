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
fileprivate struct BannerView: View {
    let message: String
    let isLoading: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            // Use a fixed-size frame for the icon area to ensure consistent sizing
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .frame(width: 16, height: 16)
            
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.vertical, 10) // Increased vertical padding for consistent height
        .padding(.horizontal, 16)
        .frame(height: 36) // Fixed height for both states
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(white: 0.1, opacity: 0.9) : Color(white: 0.95, opacity: 0.9))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Banner Manager
class BannerWindowController {
    private var window: NSWindow?
    private var isVisible = false
    private var hideTimer: Timer?
    
    // Store the Y position to ensure consistency
    private var bannerYPosition: CGFloat = 0
    
    static let shared = BannerWindowController()
    
    private init() {}
    
    func showBanner(message: String, isLoading: Bool, duration: TimeInterval = 2.5) {
        hideTimer?.invalidate()
        
        DispatchQueue.main.async {
            // Create banner content
            let bannerView = BannerView(message: message, isLoading: isLoading)
            let hostingController = NSHostingController(rootView: bannerView)
            
            // Size the view first
            let size = NSSize(width: hostingController.view.fittingSize.width, height: 36) // Force height
            
            // Create window if needed or update existing
            if self.window == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: size.width, height: 36), // Force height
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
                window.level = .statusBar
                window.collectionBehavior = [.canJoinAllSpaces, .stationary]
                window.ignoresMouseEvents = true
                window.alphaValue = 0.0
                
                self.window = window
                
                // Calculate and store Y position on first creation
                if let screen = NSScreen.main {
                    self.bannerYPosition = screen.frame.height - 36 - 75 // 75px from top
                }
            }
            
            // Update content
            self.window?.contentViewController = hostingController
            self.window?.setContentSize(size)
            
            // Position at stored Y position
            if let screen = NSScreen.main {
                let x = (screen.frame.width - size.width) / 2
                self.window?.setFrameOrigin(NSPoint(x: x, y: self.bannerYPosition))
            }
            
            // Show window
            self.window?.orderFront(nil)
            self.isVisible = true
            
            // Animate appearance
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.window?.animator().alphaValue = 1.0
            }
            
            // Schedule hiding
            if !isLoading {
                self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.hideBanner()
                }
            }
        }
    }
    
    func updateBanner(message: String, isLoading: Bool) {
        DispatchQueue.main.async {
            if self.isVisible, let window = self.window {
                // Create new banner view with updated message
                let bannerView = BannerView(message: message, isLoading: isLoading)
                let hostingController = NSHostingController(rootView: bannerView)
                
                // Update window content with forced height
                let size = NSSize(width: hostingController.view.fittingSize.width, height: 36)
                window.contentViewController = hostingController
                window.setContentSize(size)
                
                // Recenter horizontally but keep the same Y position
                if let screen = NSScreen.main {
                    let x = (screen.frame.width - size.width) / 2
                    window.setFrameOrigin(NSPoint(x: x, y: self.bannerYPosition))
                }
                
                // If not loading, start hide timer
                if !isLoading {
                    self.hideTimer?.invalidate()
                    self.hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                        self?.hideBanner()
                    }
                }
            } else {
                // If not visible, show it
                self.showBanner(message: message, isLoading: isLoading)
            }
        }
    }
    
    func hideBanner() {
        guard isVisible, let window = self.window else { return }
        
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            }, completionHandler: {
                window.orderOut(nil)
                self.isVisible = false
            })
        }
    }
}

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
        let prompt = "Extract all the text from this image. Keep the structure and formatting intact. DO NOT add any explanations or additional text."
        
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
        // Convert NSImage to CGImage for Vision processing
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to create CGImage from NSImage")
            BannerWindowController.shared.updateBanner(message: "Failed to process image", isLoading: false)
            return
        }
        
        // Create a new Vision request to recognize text
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error recognizing text: \(error)")
                BannerWindowController.shared.updateBanner(message: "Error recognizing text", isLoading: false)
                return
            }
            
            // Process the results
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // Extract recognized text
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            // Update the UI on the main thread
            DispatchQueue.main.async {
                self.lastRecognizedText = recognizedText
                
                // Copy the recognized text to clipboard
                self.copyToClipboard(text: recognizedText)
                
                // Update banner to show success
                BannerWindowController.shared.updateBanner(message: "Copied to clipboard", isLoading: false)
            }
        }
        
        // Configure the text recognition request
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        
        // Create a request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing OCR request: \(error)")
            BannerWindowController.shared.updateBanner(message: "Failed to perform OCR", isLoading: false)
        }
    }
    
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Text copied to clipboard: \(text)")
    }
    
    func displayError(_ error: Error) {
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
    
    func formatTextUsingAI(for image: NSImage) {
        guard let lastIndex = images.lastIndex(of: image) else {
            print("Image not found")
            return
        }
        
        DispatchQueue.main.async {
            self.isFormatting = true
            self.errorMessage = ""
            self.showError = false
        }
        
        // Show banner for formatting
        BannerWindowController.shared.showBanner(message: "Formatting with Gemini AI...", isLoading: true)
        
        // Default prompt for formatting text
        let prompt = "Please analyze this image and extract all the text. Format the text properly maintaining the structure, layout, and indentation. For code snippets, preserve the syntax highlighting and indentation, and remove the UI (line numbers, etc) text, only keep the actual code. For tables, maintain the tabular format. DO NOT GIVE ANY EXPLANATION OR ANY EXTRA INFORMATION. ONLY THE TEXT CONTENT."
        
        geminiAPIClient.formatImageText(image: image, prompt: prompt) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isFormatting = false
                
                switch result {
                case .success(let formattedText):
                    self.lastRecognizedText = formattedText
                    self.copyToClipboard(text: formattedText)
                    
                    // Update banner to show success
                    BannerWindowController.shared.updateBanner(message: "Formatted text copied to clipboard", isLoading: false)
                    
                case .failure(let error):
                    print("Error formatting text: \(error.localizedDescription)")
                    self.displayError(error)
                    
                    // Update banner to show error
                    BannerWindowController.shared.updateBanner(message: "Error formatting text", isLoading: false)
                }
            }
        }
    }
}
