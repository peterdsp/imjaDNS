//
//  DNSProfileView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture

struct DNSProfileView: View {
    let store: StoreOf<DNSProfileFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                ForEach(viewStore.profiles) { profile in
                    Button(action: {
                        viewStore.send(.selectProfile(profile))
                    }) {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.headline)
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
