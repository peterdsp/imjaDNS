//
//  DNSManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation
import NetworkExtension

class DNSManager {
    static let shared = DNSManager()
    private init() {}

    func getCurrentDNS() -> String {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/sbin/scutil"
        task.arguments = ["--dns"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        if let output = String(data: data, encoding: .utf8),
           let match = output.components(separatedBy: "nameserver ").dropFirst().first?.components(separatedBy: "\n").first {
            return match
        }
        return "Unknown"
        #else
        return "Auto-assigned"
        #endif
    }

    func changeDNS(to dns: String) {
        print("[DNSManager] Changing DNS to: \(dns)")

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("[DNSManager] Load error: \(error)")
                return
            }

            // Delete old imjaDNS tunnels
            managers?.forEach { existingManager in
                if existingManager.localizedDescription == "imjaDNS Tunnel" {
                    existingManager.removeFromPreferences { error in
                        if let error = error {
                            print("[DNSManager] Failed to remove old tunnel: \(error)")
                        } else {
                            print("[DNSManager] Removed old tunnel.")
                        }
                    }
                }
            }

            // Create new config
            let newManager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "dev.peterdsp.imjaDNS.DNSPacketTunnel"
            proto.serverAddress = dns // visible in VPN details
            proto.providerConfiguration = ["dns": dns]
            proto.disconnectOnSleep = false

            newManager.localizedDescription = "imjaDNS Tunnel"
            newManager.protocolConfiguration = proto
            newManager.isEnabled = true

            newManager.saveToPreferences { error in
                if let error = error {
                    print("[DNSManager] Save error: \(error)")
                    return
                }

                do {
                    try newManager.connection.startVPNTunnel()
                    print("[DNSManager] Started tunnel with DNS: \(dns)")
                } catch {
                    print("[DNSManager] Failed to start tunnel: \(error)")
                }
            }
        }
    }
}
