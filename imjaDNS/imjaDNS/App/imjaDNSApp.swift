//
//  imjaDNSApp.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture
import Firebase
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct imjaDNSApp: App {
    let profileStore = Store(initialState: DNSProfileFeature.State()) {
        DNSProfileFeature()
    }

    init() {
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    HomeView(
                        store: Store(initialState: HomeFeature.State()) {
                            HomeFeature()
                        },
                        profileStore: profileStore
                    )
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .onAppear {
                ViewStore(profileStore, observe: { $0 }).send(.onAppear)
            }
        }
    }
}
