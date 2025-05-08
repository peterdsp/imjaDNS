//
//  HomeView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.

import SwiftUI
import ComposableArchitecture
import Network
import NetworkExtension

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    let profileStore: StoreOf<DNSProfileFeature>
    
    var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active DNS:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(viewStore.currentDNS)
                            .font(.title)
                            .fontWeight(.bold)

                        Text("System DNS")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(viewStore.networkName)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        viewStore.send(.onAppear)
                        detectActiveNetwork(viewStore: viewStore)
                    }

                    Button(action: {
                        viewStore.send(.changeDNS)
                    }) {
                        Text("Change DNS")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    NavigationLink(
                        destination: DNSProfileView(
                                store: profileStore
                            )
                    ) {
                        HStack {
                            Text("Quick Profile")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding()
                .navigationTitle("imjaDNS")
                .alert(
                    "Enable DNS Configuration",
                    isPresented: viewStore.binding(
                        get: { $0.showFirstTimeDNSAlert },
                        send: { _ in .toggleDNSAlert(false) }
                    )
                ) {
                    Button("Open Settings") {
                        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList/DNS") {
                            UIApplication.shared.open(url)
                        }
                    }
                } message: {
                    Text("To activate DNS profiles, go to:\n\nSettings → General → VPN & Device Management → DNS\n\nThen select imjaDNS.")
                }
            }
        }
    }

    func detectActiveNetwork(viewStore: ViewStoreOf<HomeFeature>) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    viewStore.send(.updateNetworkName("Wi-Fi: Connected"))
                } else if path.usesInterfaceType(.wiredEthernet) {
                    viewStore.send(.updateNetworkName("Ethernet: Connected"))
                } else if path.usesInterfaceType(.cellular) {
                    viewStore.send(.updateNetworkName("Cellular: Connected"))
                } else {
                    viewStore.send(.updateNetworkName("No Connection"))
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }
}
