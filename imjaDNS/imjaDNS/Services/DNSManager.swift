import Foundation
import NetworkExtension
import os.log

enum DNSError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case invalidServer(String)
    case noServersProvided
    case configurationNotFound

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load DNS configuration: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save DNS configuration: \(error.localizedDescription)"
        case .invalidServer(let server):
            return "Invalid DNS server address: \(server)"
        case .noServersProvided:
            return "No DNS servers were provided"
        case .configurationNotFound:
            return "DNS configuration not found on this device"
        }
    }
}

@MainActor
final class DNSManager {
    static let shared = DNSManager()
    private init() {}

    private let log = Logger(subsystem: "dev.peterdsp.imjaDNS", category: "DNS")

    func currentServers() async -> [String] {
        do {
            let mgr = NEDNSSettingsManager.shared()
            try await mgr.loadFromPreferences()

            guard let dnsSettings = mgr.dnsSettings,
                  !dnsSettings.servers.isEmpty else {
                return []
            }

            return dnsSettings.servers
        } catch {
            log.error("Failed to load DNS config: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func currentServersDisplay() async -> String {
        let servers = await currentServers()
        return servers.isEmpty ? "System Default" : servers.joined(separator: ", ")
    }

    func isCustomDNSActive() async -> Bool {
        let servers = await currentServers()
        return !servers.isEmpty
    }

    func applyProfile(_ profile: DNSProfile) async throws {
        guard !profile.servers.isEmpty else {
            throw DNSError.noServersProvided
        }

        for server in profile.servers {
            guard DNSValidation.isValidDNSServer(server) else {
                throw DNSError.invalidServer(server)
            }
        }

        let mgr = NEDNSSettingsManager.shared()

        do {
            try await mgr.loadFromPreferences()
        } catch {
            throw DNSError.loadFailed(error)
        }

        switch profile.protocolType {
        case .doh:
            if let dohURL = profile.dohURL, let url = URL(string: dohURL) {
                let settings = NEDNSOverHTTPSSettings(servers: profile.servers)
                settings.serverURL = url
                settings.matchDomains = [""]
                mgr.dnsSettings = settings
            } else {
                let settings = NEDNSSettings(servers: profile.servers)
                settings.matchDomains = [""]
                mgr.dnsSettings = settings
            }

        case .dot:
            if let hostname = profile.dotHostname {
                let settings = NEDNSOverTLSSettings(servers: profile.servers)
                settings.serverName = hostname
                settings.matchDomains = [""]
                mgr.dnsSettings = settings
            } else {
                let settings = NEDNSSettings(servers: profile.servers)
                settings.matchDomains = [""]
                mgr.dnsSettings = settings
            }

        case .plain:
            let settings = NEDNSSettings(servers: profile.servers)
            settings.matchDomains = [""]
            mgr.dnsSettings = settings
        }

        do {
            try await mgr.saveToPreferences()
            try await mgr.loadFromPreferences()
            log.info("DNS applied: \(profile.name, privacy: .public) [\(profile.servers.joined(separator: ", "), privacy: .public)]")
        } catch {
            throw DNSError.saveFailed(error)
        }
    }

    func disableCustomDNS() async throws {
        let mgr = NEDNSSettingsManager.shared()

        do {
            try await mgr.loadFromPreferences()
        } catch {
            throw DNSError.loadFailed(error)
        }

        mgr.dnsSettings = nil

        do {
            try await mgr.saveToPreferences()
            log.info("Custom DNS disabled, reverted to system default")
        } catch {
            throw DNSError.saveFailed(error)
        }
    }

    func testLatency(server: String, timeout: TimeInterval = 5) async -> Double? {
        guard DNSValidation.isValidIPv4(server) || DNSValidation.isValidIPv6(server) else {
            return nil
        }

        let start = CFAbsoluteTimeGetCurrent()

        guard let url = URL(string: "http://\(server)") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "HEAD"

        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            let session = URLSession(configuration: config)
            _ = try await session.data(for: request)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            return elapsed
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            if elapsed < timeout * 1000 {
                return elapsed
            }
            return nil
        }
    }

    func testProfileLatency(_ profile: DNSProfile) async -> Double? {
        var results: [Double] = []

        for server in profile.servers {
            if let latency = await testLatency(server: server) {
                results.append(latency)
            }
        }

        guard !results.isEmpty else { return nil }
        return results.min()
    }
}
