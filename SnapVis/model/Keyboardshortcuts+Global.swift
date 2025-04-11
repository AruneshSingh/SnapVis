//
//  Keyboardshortcuts+Global.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 30/01/25.
//

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let screenshotCapture = Self("screenshotCapture", default:.init(.three, modifiers: [.option, .command]))
    static let promptedScreenshotCapture = Self("promptedScreenshotCapture", default: .init(.two, modifiers: [.command]))
}


