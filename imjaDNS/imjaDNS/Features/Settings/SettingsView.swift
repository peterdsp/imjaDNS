//
//  SettingsView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 07/05/2025.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @AppStorage("autoApplyDNS") private var autoApplyDNS = false

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Auto-Apply DNS", isOn: $autoApplyDNS)

                Button("Open System DNS Settings") {
                    if let url = URL(string: "App-Prefs:root=General&path=Network") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func openSystemVPNSettings() {
        // This opens the VPN settings pane on iOS
        if let url = URL(string: "App-Prefs:root=General&path=VPN"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("⚠️ Cannot open VPN settings. Ensure App-Prefs is allowed.")
        }
    }
}
