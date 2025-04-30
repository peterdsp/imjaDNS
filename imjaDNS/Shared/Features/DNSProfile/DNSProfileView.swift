//
//  DNSProfileView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture

struct DNSProfileView: View {
    @State private var store = Store(initialState: DNSProfileFeature.State()) {
        DNSProfileFeature()
    }

    var body: some View {
        WithViewStore(store, observe: \ .self) { viewStore in
            List {
                ForEach(viewStore.profiles) { profile in
                    Button(action: {
                        ViewStore(store).send(.selectProfile(profile))
                    }) {
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.headline)
                            Text(profile.servers.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profiles")
        }
    }
}
