//
//  MenubarContentView.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 01/02/25.
//

import SwiftUI

struct MenubarContentView: View {
    
    @ObservedObject var vm: ScreencaptureViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
//            Button("Open App") {
//                openWindow(id: "main")
//            }
            
            Button("Select area") {
                vm.takeScreenShot(for: .area, processImmediately: true)
            }
            
            // Button to re-open the chat window
            Button("Show Last Response") {
                vm.showingChatResponseWindow = true // Signal to open the window
            }
            // Only enable if there's an image/prompt/response from a previous prompted flow
            .disabled(vm.promptedScreenshotImage == nil || vm.userPrompt.isEmpty)
            
            Divider()
            
            SettingsLink {
                Text("Settings")
            }
            
            Divider()
            
            Button {
                openURL(URL(string: "https://discord.gg/yourlink")!)
            } label: {
                Label("Community/Feedback", systemImage: "bubble.left.and.bubble.right.fill")
            }
            
            Button {
                openURL(URL(string: "https://twitter.com/youraccount")!)
            } label: {
                Label("Follow", systemImage: "bird.fill")
            }
            
            Divider()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 200)
        .padding()
    }
}
