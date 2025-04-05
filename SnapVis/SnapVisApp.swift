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
        
        MenuBarExtra("Screenshots", systemImage: "photo.badge.plus", isInserted: $menuBarExtraIsStored){
            MenubarContentView(vm: vm)
        }
        
        WindowGroup("Screenshots", id: "main") {
            ContentView(vm: vm)
        }
        .defaultSize(width: 800, height: 600)
        
        Settings {
            SettingsView()
        }
    }
}
