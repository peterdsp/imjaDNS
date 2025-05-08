//
//  DNSManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation
import NetworkExtension
import os.log

@MainActor
final class DNSManager {
    static let shared = DNSManager()
    private init() {}

    private let log = Logger(subsystem: "dev.peterdsp.imjaDNS", category: "DNS")

    func currentServers() async -> String {
        do {
            let mgr = NEDNSSettingsManager.shared()
            try await mgr.loadFromPreferences()

            guard let dnsSettings = mgr.dnsSettings,
                  !dnsSettings.servers.isEmpty else {
                return "Auto-assigned"
            }

            return dnsSettings.servers.joined(separator: ", ")
        } catch {
            log.error("Failed to load DNS config: \(String(describing: error), privacy: .public)")
            return "Auto-assigned"
        }
    }

    func setServers(_ servers: [String], matchDomains: [String] = [""]) async throws {
        let mgr = NEDNSSettingsManager.shared()
        try await mgr.loadFromPreferences()

        let settings = NEDNSSettings(servers: servers)
        settings.matchDomains = matchDomains.isEmpty ? nil : matchDomains
        mgr.dnsSettings = settings

        try await mgr.saveToPreferences()
        try await mgr.loadFromPreferences()

        if let primary = servers.first {
            UserDefaults.standard.set(primary, forKey: "lastUsedDNS")
        }
    }

    func disableCustomDNS() async {
        do {
            let mgr = NEDNSSettingsManager.shared()
            try await mgr.loadFromPreferences()
            mgr.dnsSettings = nil
            try await mgr.saveToPreferences()
        } catch {
            log.error("Failed to disable DNS: \(String(describing: error), privacy: .public)")
        }
    }
    func getCurrentDNS() async -> String {
        await currentServers()
    }

    func changeDNS(to dns: String) {
        Task {
            try? await setServers([dns])
            UserDefaults.standard.set(dns, forKey: "lastUsedDNS")
        }
    }
}
