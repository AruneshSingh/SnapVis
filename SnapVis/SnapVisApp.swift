//
//  ScreenshotAppApp.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 24/01/25.
//

import SwiftUI
import PostHog

@main
struct SnapVisApp: App {
    
    // Environment value for opening windows programmatically
    @Environment(\.openWindow) var openWindow
    
    init() {
            
        let POSTHOG_API_KEY = "phc_JRYQ4Qg9E5svGsDrR0b6NG220AXfViT8i28oIyNvKXl"
        // usually 'https://us.i.posthog.com' or 'https://eu.i.posthog.com'
        let POSTHOG_HOST = "https://us.i.posthog.com"
        
        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST) // host is optional if you use https://us.i.posthog.com
        PostHogSDK.shared.setup(config)
        
    }
    
    @StateObject var vm = ScreencaptureViewModel()
    
    @AppStorage("menuBarExtraIsStored") var menuBarExtraIsStored = true
    
    var body: some Scene {
        
        MenuBarExtra(isInserted: $menuBarExtraIsStored){
            MenubarContentView(vm: vm)
        } label: {
            // Your menu bar icon
            Image("menubar_icon")
        }
        
        
        Settings {
            SettingsView()
        }
        
        // New Window for Prompt Input
        Window("Enter Prompt", id: "prompt-input-window") {
            if vm.showingPromptInputWindow {
                PromptInputView { submittedPrompt in
                    // Handle prompt submission
                    vm.showingPromptInputWindow = false // Close this window
                    vm.submitPromptForProcessing(prompt: submittedPrompt) // Call the VM function
                }
                .environmentObject(vm)
            }
        }
        .windowResizability(.contentSize) // Adjust size to content
        .defaultPosition(.center) // Or position near screenshot?
        // Control visibility via the view model state
        .onChange(of: vm.showingPromptInputWindow) { oldValue, newValue in
            print("showingPromptInputWindow changed from \(oldValue) to: \(newValue)")
            Task {
                if newValue {
                    print("Attempting to open prompt-input-window") 
                    openWindow(id: "prompt-input-window") // Open the window
                    
                    // Attempt to bring the window to the front
                    // Need a slight delay to allow the window to open before finding it
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    DispatchQueue.main.async {
                         // Find the window by its ID (if set consistently) or title
                        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "prompt-input-window" }) {
                             print("Found prompt window, making key and ordering front.")
                             window.makeKeyAndOrderFront(nil)
                             NSApp.activate(ignoringOtherApps: true) // Ensure the app itself is active
                         } else {
                             print("Could not find prompt window by ID to bring to front.")
                         }
                    }
                    
                } else {
                    // Optionally add code to explicitly close the window if needed
                    print("showingPromptInputWindow is false, window should close or already be closed.")
                }
            }
        }
        
        // Window for Chat Response
        Window("Gemini Response", id: "chat-response-window") {
            // Pass necessary data from the ViewModel to the ChatResponseView
            ChatResponseView(
                image: vm.promptedScreenshotImage, 
                prompt: vm.userPrompt, 
                response: vm.apiResponse, 
                isLoading: vm.isLoadingResponse
            )
            .environmentObject(vm) // Pass VM if needed for actions within the view
            .onDisappear { // Apply to the view inside the window
                // Reset state when the window is closed by the user
                vm.showingChatResponseWindow = false
                // Consider clearing other related state like image, prompt, response?
                // vm.promptedScreenshotImage = nil
                // vm.userPrompt = ""
                // vm.apiResponse = nil
            }
        }
        // Control visibility via the view model state
        .handlesExternalEvents(matching: ["chat-response-window"]) // Allows opening/closing programmatically
        .onChange(of: vm.showingChatResponseWindow) { oldValue, newValue in
            Task {
                if newValue {
                    openWindow(id: "chat-response-window")
                } else {
                    // Closing programmatically might need Environment DismissAction or other window handling
                } 
            }
        }
    }
}
