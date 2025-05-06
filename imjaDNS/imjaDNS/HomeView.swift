//
//  HomeView.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import SwiftUI
import ComposableArchitecture
import Network
import NetworkExtension
import CoreLocation
import CoreTelephony

#if os(iOS)
import SystemConfiguration.CaptiveNetwork
#endif

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @State private var networkName: String = "..."
    @State private var currentSystemDNS: String = "..."
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationAlert = false
    
    var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active DNS:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(currentSystemDNS)
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

                        Text(networkName)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        detectActiveNetwork()
                        loadSystemDNS()

                        if CLLocationManager.authorizationStatus() == .denied || CLLocationManager.authorizationStatus() == .restricted {
                            showLocationAlert = true
                        }
                    }
                    .alert("Location Required", isPresented: $showLocationAlert) {
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
                            NavigationStack {
                                DNSProfileView(
                                    store: Store(initialState: DNSProfileFeature.State()) {
                                        DNSProfileFeature()
                                    }
                                )
                            }
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

    func detectActiveNetwork() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    #if os(iOS)
                    let ssid = fetchSSID() ?? "Wi-Fi"
                    self.networkName = "Wi-Fi: \(ssid)"
                    #else
                    self.networkName = "Wi-Fi"
                    #endif
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.networkName = "Ethernet: Connected"
                } else if path.usesInterfaceType(.cellular) {
                    let carrier = getCarrierName() ?? "Cellular"
                    self.networkName = "Cellular: \(carrier)"
                } else {
                    self.networkName = "No Connection"
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }

    #if os(iOS)
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
                print("[Network] No carrier info available")
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
    #endif

    func loadSystemDNS() {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/sbin/scutil"
        task.arguments = ["--dns"]

        let pipe = Pipe()
        task.standardOutput = pipe

        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if let output = String(data: data, encoding: .utf8) {
            if let match = output.components(separatedBy: "nameserver ").dropFirst().first?.components(separatedBy: "\n").first {
                DispatchQueue.main.async {
                    self.currentSystemDNS = match
                }
            }
        }
        #else
        self.currentSystemDNS = "Auto-assigned"
        #endif
    }
    
    func setupAndStartVPN() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("Error loading preferences: \(error)")
                return
            }

            let manager = managers?.first ?? NETunnelProviderManager()
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = "com.yourcompany.imjaDNS.DNSPacketTunnel"
            protocolConfiguration.serverAddress = "DNS VPN"

            manager.protocolConfiguration = protocolConfiguration
            manager.localizedDescription = "imjaDNS VPN"
            manager.isEnabled = true

            manager.saveToPreferences { error in
                if let error = error {
                    print("Error saving preferences: \(error)")
                    return
                }

                do {
                    try manager.connection.startVPNTunnel()
                    print("VPN started successfully.")
                } catch {
                    print("Error starting VPN: \(error)")
                }
            }
        }
    }
}
