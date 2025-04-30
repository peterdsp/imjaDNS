//
//  HomeView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithViewStore(store, observe: \ .self) { viewStore in
            VStack(spacing: 16) {
                Text("Active DNS: \(viewStore.currentDNS)")
                    .font(.title2)
                    .padding(.top)

                Text("Network: Wi-Fi: Office Network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Change DNS") {
                    viewStore.send(.changeDNS)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Quick Profile", destination: DNSProfileView())
                    .padding(.top)

                Spacer()
            }
            .padding()
            .navigationTitle("imjaDNS")
        }
    }
}
