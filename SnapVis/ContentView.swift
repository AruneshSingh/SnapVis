//
//  ContentView.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 24/01/25.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var vm: ScreencaptureViewModel
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))]) {
                    ForEach (vm.images, id: \.self) { image in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
//                            .onDrag ({ NSItemProvider(object: image) })
                            .draggable(image)
                    }
                }
            }
            
            // Show loading indicator when processing with Gemini API
            if vm.isFormatting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                    Text("Processing with Gemini AI...")
                        .font(.footnote)
                }
                .padding(.vertical, 8)
            }
            
            // Display recognized text if available
            if !vm.lastRecognizedText.isEmpty {
                VStack(alignment: .leading) {
                    Text("Recognized Text:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(vm.lastRecognizedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    // Error message if present
                    if vm.showError {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                    
                    HStack {
                        Button("Copy Text to Clipboard") {
                            vm.copyToClipboard(text: vm.lastRecognizedText)
                        }
                        
                        if vm.images.count > 0 {
                            Button {
                                if let lastImage = vm.images.last {
                                    vm.formatTextUsingAI(for: lastImage)
                                }
                            } label: {
                                HStack {
                                    if vm.isFormatting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .padding(.trailing, 2)
                                    }
                                    Text("Format using Gemini AI")
                                }
                            }
                            .disabled(vm.isFormatting)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            HStack {            
                Button("Make an area screenshot") {
                    vm.takeScreenShot(for: .area)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(vm: ScreencaptureViewModel())
}
