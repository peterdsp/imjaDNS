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
    
    func getCurrentDNS() async -> String {
        await withCheckedContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    print("[DNSManager] Error loading preferences: \(error)")
                    continuation.resume(returning: "Auto-assigned")
                    return
                }
                
                guard let manager = managers?.first(where: { $0.localizedDescription == "imjaDNS Tunnel" }),
                      let dns = (manager.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerConfiguration?["dns"] as? String,
                      !dns.isEmpty else {
                    continuation.resume(returning: "Auto-assigned")
                    return
                }
                
                continuation.resume(returning: dns)
            }
        }
    }
    
    func changeDNS(to dns: String) {
        print("[DNSManager] Changing DNS to: \(dns)")
        
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("[DNSManager] Load error: \(error)")
                return
            }
            
            // Remove old tunnels
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
            
            // Create and configure new manager
            let newManager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "dev.peterdsp.imjaDNS.DNSPacketTunnel"
            proto.serverAddress = dns
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
                
                // Important: Load again to sync internal state
                newManager.loadFromPreferences { error in
                    if let error = error {
                        print("[DNSManager] Load after save error: \(error)")
                        return
                    }
                    
                    do {
                        try newManager.connection.startVPNTunnel()
                        print("[DNSManager] Successfully started tunnel for DNS: \(dns)")
                    } catch {
                        print("[DNSManager] Failed to start tunnel after save/load: \(error)")
                    }
                }
            }
        }
    }
}
