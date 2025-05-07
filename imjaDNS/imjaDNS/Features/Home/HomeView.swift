//
//  HomeView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.

import SwiftUI
import ComposableArchitecture
import Network
import NetworkExtension
import CoreLocation
import CoreTelephony
import SystemConfiguration.CaptiveNetwork

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @StateObject private var locationManager = LocationManager()

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

                        if CLLocationManager.authorizationStatus() == .denied || CLLocationManager.authorizationStatus() == .restricted {
                            viewStore.send(.toggleLocationAlert(true))
                        }
                    }
                    .alert("Location Required", isPresented: viewStore.binding(
                        get: \.showLocationAlert,
                        send: .toggleLocationAlert(false)
                    )) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("We need location access to detect your current Wi-Fi network.")
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
                        destination:
                            DNSProfileView(
                                store: Store(initialState: DNSProfileFeature.State()) {
                                    DNSProfileFeature()
                                }
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
            }
        }
    }

    func detectActiveNetwork(viewStore: ViewStoreOf<HomeFeature>) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    let ssid = fetchSSID() ?? "Wi-Fi"
                    viewStore.send(.updateNetworkName("Wi-Fi: \(ssid)"))
                } else if path.usesInterfaceType(.wiredEthernet) {
                    viewStore.send(.updateNetworkName("Ethernet: Connected"))
                } else if path.usesInterfaceType(.cellular) {
                    let carrier = getCarrierName() ?? "Cellular"
                    viewStore.send(.updateNetworkName("Cellular: \(carrier)"))
                } else {
                    viewStore.send(.updateNetworkName("No Connection"))
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }

    func fetchSSID() -> String? {
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let dict = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? {
                    return dict[kCNNetworkInfoKeySSID as String] as? String
                }
            }
        }
        return nil
    }

    func getCarrierName() -> String? {
        let networkInfo = CTTelephonyNetworkInfo()

        if #available(iOS 12.0, *) {
            guard let carriers = networkInfo.serviceSubscriberCellularProviders else {
                return nil
            }
            for carrier in carriers.values {
                if let name = carrier.carrierName {
                    return name
                }
            }
        } else {
            if let carrier = networkInfo.subscriberCellularProvider,
               let name = carrier.carrierName {
                return name
            }
        }

        return nil
    }
}
