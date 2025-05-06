//
//  imjaDNSApp.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Auto-Apply DNS", isOn: .constant(true))
                Button("Open System DNS Settings") {
                    // Implement native bridge or open URL
                }
            }
        }
        .navigationTitle("Settings")
    }
}

@main
struct imjaDNSApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            TabView {
                NavigationStack {
                    HomeView(
                        store: Store(initialState: HomeFeature.State()) {
                            HomeFeature()
                        }
                    )
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }

                NavigationStack {
                    DNSProfileView(
                        store: Store(initialState: DNSProfileFeature.State()) {
                            DNSProfileFeature()
                        }
                    )
                }
                .tabItem {
                    Label("Profiles", systemImage: "plus.circle")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            #else
            NavigationStack {
                VStack(spacing: 0) {
                    HomeView(
                        store: Store(initialState: HomeFeature.State()) {
                            HomeFeature()
                        }
                    )
                    Spacer()
                    Divider()
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .buttonStyle(.plain)

                        Toggle(isOn: .constant(true)) {
                            Text("Auto-Apply")
                        }
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding()
                }
            }
            .frame(minWidth: 400, idealWidth: 400, maxWidth: 400,
                   minHeight: 600, idealHeight: 600, maxHeight: 600)
            #endif
        }
        .windowResizability(.contentSize)
    }
}
