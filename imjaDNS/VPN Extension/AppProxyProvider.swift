//
//  AppProxyProvider.swift
//  DNSPacketTunnel
//
//  Created by Petros Dhespollari on 06/05/2025.
//

import NetworkExtension

class AppProxyProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Get DNS from provider configuration
        let dnsServers = (self.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["dns"] as? String

        guard let dns = dnsServers else {
            NSLog("[AppProxyProvider] No DNS found in provider configuration.")
            completionHandler(NSError(domain: "AppProxyProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing DNS in provider config"]))
            return
        }

        NSLog("[AppProxyProvider] Starting tunnel with DNS: \(dns)")

        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // Apply passed DNS
        let dnsSettings = NEDNSSettings(servers: [dns])
        tunnelNetworkSettings.dnsSettings = dnsSettings

        // Dummy IP settings required by system (not used for actual routing here)
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings

        // Apply network settings
        setTunnelNetworkSettings(tunnelNetworkSettings) { error in
            if let error = error {
                NSLog("[AppProxyProvider] Failed to apply tunnel settings: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                NSLog("[AppProxyProvider] Tunnel settings applied successfully.")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[AppProxyProvider] Tunnel stopped with reason: \(reason.rawValue)")
        completionHandler()
    }
}
