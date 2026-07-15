import Foundation

/// On-device DNS trust checks. Everything is user-initiated; the only network
/// calls are explicit DNS queries to the active resolver — no personal data,
/// no third-party analytics.
enum DNSDiagnostics {
    enum Status: String, Equatable, Sendable {
        case pass, warn, fail, unknown
    }

    struct Check: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        var status: Status
        var detail: String
    }

    struct Report: Equatable, Sendable {
        var encryption: Check
        var reachability: Check
        var dnssec: Check
        var overall: Status

        var checks: [Check] { [encryption, reachability, dnssec] }
    }

    // Control domains. example.com is IANA-reserved and always resolvable;
    // dnssec-failed.org is a public testbed that SERVFAILs from validating
    // resolvers.
    private static let reachabilityDomain = "example.com"
    private static let dnssecBrokenDomain = "dnssec-failed.org"

    /// Runs all checks against the currently-active profile (or the system's
    /// current servers when no custom profile is applied).
    @MainActor
    static func run() async -> Report {
        let timeout = SpeedProbe.adaptiveTimeout()
        let active = await ProfileProvider.activeProfile()
        let servers: [String]
        if let active {
            servers = active.servers
        } else {
            servers = await DNSManager.shared.currentServers()
        }
        let probeServer = servers.first { DNSValidation.isValidDNSServer($0) }

        let encryption = encryptionCheck(active)
        let reachability = await reachabilityCheck(server: probeServer, timeout: timeout)
        let dnssec = await dnssecCheck(server: probeServer, timeout: timeout)

        return Report(
            encryption: encryption,
            reachability: reachability,
            dnssec: dnssec,
            overall: combine([encryption.status, reachability.status, dnssec.status])
        )
    }

    // MARK: - Pure interpreters (unit-tested)

    static func encryptionCheck(_ profile: DNSProfile?) -> Check {
        guard let profile else {
            return Check(id: "encryption", title: "Encryption", status: .warn, detail: "Using system default DNS")
        }
        switch profile.protocolType {
        case .doh:
            return Check(id: "encryption", title: "Encryption", status: .pass, detail: "DNS over HTTPS — encrypted")
        case .dot:
            return Check(id: "encryption", title: "Encryption", status: .pass, detail: "DNS over TLS — encrypted")
        case .plain:
            return Check(id: "encryption", title: "Encryption", status: .warn, detail: "Plain DNS — not encrypted")
        }
    }

    static func interpretReachability(_ response: DNSLatencyTester.DNSResponse?, server: String) -> Check {
        guard let response else {
            return Check(id: "reachability", title: "Reachability", status: .fail, detail: "No response from \(server)")
        }
        if response.rcode == 0 {
            return Check(id: "reachability", title: "Reachability", status: .pass,
                         detail: "\(server) · \(Int(response.rtt.rounded())) ms")
        }
        return Check(id: "reachability", title: "Reachability", status: .warn,
                     detail: "\(server) responded (RCODE \(response.rcode))")
    }

    static func interpretDNSSEC(_ response: DNSLatencyTester.DNSResponse?) -> Check {
        guard let response else {
            return Check(id: "dnssec", title: "DNSSEC", status: .unknown, detail: "Inconclusive — no response")
        }
        switch response.rcode {
        case 2:  // SERVFAIL — validating resolver rejected the broken domain
            return Check(id: "dnssec", title: "DNSSEC", status: .pass, detail: "Validating — rejected broken domain")
        case 0:  // NOERROR — resolved a domain a validating resolver would reject
            return Check(id: "dnssec", title: "DNSSEC", status: .warn, detail: "Not validating — resolved broken domain")
        default:
            return Check(id: "dnssec", title: "DNSSEC", status: .unknown, detail: "Inconclusive (RCODE \(response.rcode))")
        }
    }

    /// Overall severity: any fail → fail; else any warn/unknown → warn; else pass.
    static func combine(_ statuses: [Status]) -> Status {
        if statuses.contains(.fail) { return .fail }
        if statuses.contains(where: { $0 == .warn || $0 == .unknown }) { return .warn }
        return .pass
    }

    // MARK: - Network checks

    private static func reachabilityCheck(server: String?, timeout: TimeInterval) async -> Check {
        guard let server else {
            return Check(id: "reachability", title: "Reachability", status: .unknown, detail: "No resolver to test")
        }
        let response = await DNSLatencyTester.queryUDP(server: server, domain: reachabilityDomain, timeout: timeout)
        return interpretReachability(response, server: server)
    }

    private static func dnssecCheck(server: String?, timeout: TimeInterval) async -> Check {
        guard let server else {
            return Check(id: "dnssec", title: "DNSSEC", status: .unknown, detail: "No resolver to test")
        }
        let response = await DNSLatencyTester.queryUDP(server: server, domain: dnssecBrokenDomain, timeout: timeout)
        return interpretDNSSEC(response)
    }
}
