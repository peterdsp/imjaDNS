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

    @State private var selectedIndex = 0
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.75
    private let cardSpacing: CGFloat = 16

    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            ScrollView {
                VStack(spacing: 28) {
                    Text("Scroll Through DNS Options")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if vs.isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // MARK: - Carousel with Peeking Cards
                        TabView(selection: $selectedIndex) {
                            ForEach(vs.profiles.indices, id: \.self) { index in
                                let profile = vs.profiles[index]
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 60, height: 60)
                                        Text(String(profile.name.prefix(1)))
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }

                                    Text("\(profile.name)")
                                        .font(.headline)

                                    Text(profile.servers)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(width: cardWidth, height: 180)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(radius: 3)
                                )
                                .tag(index)
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width, height: 220) // full-width carousel
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }

                    // MARK: - Apply DNS Button
                    Button("Apply DNS") {
                        if vs.profiles.indices.contains(selectedIndex) {
                            vs.send(.selectProfile(vs.profiles[selectedIndex]))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)

                    // MARK: - Custom DNS Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Custom DNS")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        HStack {
                            TextField(
                                "Enter custom DNS",
                                text: vs.binding(
                                    get: \.customDNS,
                                    send: DNSProfileFeature.Action.updateCustomDNS
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)

                            Button("Add") {
                                vs.send(.addCustomDNS)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top)
                .navigationTitle("Profiles")
            }
        }
    }
}
