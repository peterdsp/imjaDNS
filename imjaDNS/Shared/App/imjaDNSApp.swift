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
            HomeView(
                store: Store(initialState: HomeFeature.State()) {
                    HomeFeature()
                }
            )
        }
    }
}
