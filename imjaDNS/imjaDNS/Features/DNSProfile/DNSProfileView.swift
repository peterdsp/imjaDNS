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
            VStack {
                if viewStore.isLoading {
                    ProgressView("Loading DNS profiles...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewStore.profiles) { profile in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text(profile.servers.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewStore.selectedProfileID == profile.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewStore.send(.selectProfile(profile))
                            }
                        }
                    }
                    HStack {
                        TextField("Enter custom DNS", text: viewStore.binding(
                            get: { $0.customDNS },
                            send: DNSProfileFeature.Action.updateCustomDNS
                        ))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)

                        Button("Add") {
                            viewStore.send(.addCustomDNS)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profiles")
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}
