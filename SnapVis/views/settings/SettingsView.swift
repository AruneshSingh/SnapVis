//
//  SettingsView.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 01/02/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            KeyboardShortcutSettingsView()
                .tabItem {Label("Keyboard", systemImage: "keyboard")}
            
//            MenuBarSettingsView()
//                .tabItem {Label("MenuBarExtra", systemImage: "gear")}
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
