//
//  MenuBarSettingsView.swift
//  ScreenshotApp
//
//  Created by Arunesh Singh on 01/02/25.
//

import SwiftUI

struct MenuBarSettingsView: View {
    
    @AppStorage("menuBarExtraIsStored") var menuBarExtraIsStored = true
    
    var body: some View {
        Form {
            Toggle("Show MenuBarExtra", isOn: $menuBarExtraIsStored)
        }
    }
}

#Preview {
    MenuBarSettingsView()
}
