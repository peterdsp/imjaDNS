//
//  imjaDNSApp.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture

@main
struct imjaDNSApp: App {
    var body: some Scene {
        WindowGroup {
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
        }
    }
}
