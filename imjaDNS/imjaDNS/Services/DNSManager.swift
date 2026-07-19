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

/// What the system is actually doing with our configuration. Installing a
/// profile is not enough to make it take effect: `NEDNSSettingsManager.isEnabled`
/// is read-only, and only the user can switch the profile on, in Settings.
/// Until they do, the servers are installed but iOS still resolves through the
/// system default.
enum DNSStatus: Equatable, Sendable {
    /// Nothing installed — the system resolver is in use.
    case off
    /// Installed, but not switched on by the user, so it is not in effect.
    case installedNotEnabled
    /// Installed and in effect.
    case active
}

extension Notification.Name {
    /// Posted when the DNS configuration changes — including when the user
    /// enables or disables the profile from Settings, outside the app.
    static let dnsConfigurationDidChange = NSNotification.Name.NEDNSSettingsConfigurationDidChange
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

    /// Whether our DNS is installed, and whether the system is honouring it.
    func status() async -> DNSStatus {
        let mgr = NEDNSSettingsManager.shared()
        do {
            try await mgr.loadFromPreferences()
        } catch {
            log.error("Failed to load DNS config: \(error.localizedDescription, privacy: .public)")
            return .off
        }

        guard let settings = mgr.dnsSettings, !settings.servers.isEmpty else { return .off }
        return mgr.isEnabled ? .active : .installedNotEnabled
    }

    /// True only when the servers are actually resolving traffic. A profile the
    /// user has not enabled in Settings is installed but inert, so it does not
    /// count as active.
    func isCustomDNSActive() async -> Bool {
        await status() == .active
    }

    /// When a profile's DNS should be active. `.always` applies system-wide;
    /// the scoped cases install `onDemandRules` so iOS enforces the DNS only on
    /// that network — even in the background, with the app closed.
    enum NetworkCondition: Equatable, Sendable {
        case always
        case cellularOnly
        case wifiOnly
        case ssidOnly([String])
    }

    func applyProfile(_ profile: DNSProfile) async throws {
        try await applyProfile(profile, condition: .always)
    }

    func applyProfile(_ profile: DNSProfile, condition: NetworkCondition) async throws {
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

        mgr.onDemandRules = Self.onDemandRules(for: condition)

        do {
            try await mgr.saveToPreferences()
            try await mgr.loadFromPreferences()
            log.info("DNS applied: \(profile.name, privacy: .public) [\(profile.servers.joined(separator: ", "), privacy: .public)] condition=\(String(describing: condition), privacy: .public)")
        } catch {
            throw DNSError.saveFailed(error)
        }
    }

    /// Builds the on-demand rules for a network condition. `nil` means always on.
    private static func onDemandRules(for condition: NetworkCondition) -> [NEOnDemandRule]? {
        switch condition {
        case .always:
            return nil
        case .cellularOnly:
            let connect = NEOnDemandRuleConnect()
            connect.interfaceTypeMatch = .cellular
            let off = NEOnDemandRuleDisconnect()
            off.interfaceTypeMatch = .any
            return [connect, off]
        case .wifiOnly:
            let connect = NEOnDemandRuleConnect()
            connect.interfaceTypeMatch = .wiFi
            let off = NEOnDemandRuleDisconnect()
            off.interfaceTypeMatch = .any
            return [connect, off]
        case .ssidOnly(let ssids):
            let connect = NEOnDemandRuleConnect()
            connect.interfaceTypeMatch = .wiFi
            connect.ssidMatch = ssids
            let off = NEOnDemandRuleDisconnect()
            off.interfaceTypeMatch = .any
            return [connect, off]
        }
    }

    func disableCustomDNS() async throws {
        let mgr = NEDNSSettingsManager.shared()

        do {
            try await mgr.loadFromPreferences()
        } catch {
            throw DNSError.loadFailed(error)
        }

        // Already on the system resolver — removing again would fail.
        guard mgr.dnsSettings != nil else {
            log.info("No custom DNS installed, nothing to disable")
            return
        }

        do {
            // `saveToPreferences` rejects a manager whose `dnsSettings` is nil
            // ("configuration is invalid: Missing settings"), so clearing the
            // settings and saving cannot remove a profile — the configuration
            // itself has to go.
            try await mgr.removeFromPreferences()
            log.info("Custom DNS disabled, reverted to system default")
        } catch {
            throw DNSError.saveFailed(error)
        }
    }

    /// Measures real DNS round-trip latency to a plain resolver (UDP/53).
    func testLatency(server: String, timeout: TimeInterval = 4) async -> Double? {
        let plain = DNSProfile(name: server, servers: [server], protocolType: .plain)
        return await DNSLatencyTester.measure(profile: plain, timeout: timeout)
    }

    /// Measures latency for a profile using its actual transport (DoH/DoT/plain).
    func testProfileLatency(_ profile: DNSProfile) async -> Double? {
        await DNSLatencyTester.measure(profile: profile)
    }
}
