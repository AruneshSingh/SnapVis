//
//  KeyboardShortcutSettingsView.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 01/02/25.
//

import SwiftUI
import KeyboardShortcuts


struct KeyboardShortcutSettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Screenshot Area:", name:.screenshotCapture)
        }
        .padding()
    }
}
