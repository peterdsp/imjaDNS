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
            Section(header: Text("System DNS Setup")) {
                Button("Open VPN & Device Management") {
                    openDeviceManagementSettings()
                }

                Text("To activate DNS profiles, go to:\n\nSettings → General → VPN & Device Management → DNS\n\nThen select imjaDNS.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func openDeviceManagementSettings() {
        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
