import Foundation
import WidgetKit

/// Testable seam over the DNS operations. `DNSManager` conforms in production;
/// tests and intents depend on the protocol so the singleton can be stubbed.
@MainActor
protocol DNSApplying {
    func applyProfile(_ profile: DNSProfile) async throws
    func disableCustomDNS() async throws
    func testProfileLatency(_ profile: DNSProfile) async -> Double?
    func currentServersDisplay() async -> String
}

extension DNSManager: DNSApplying {}

/// One place to apply or remove DNS with a consistent set of side effects,
/// shared by the DNSProfile reducer, App Intents, the Control Center toggle,
/// and (later) the automation engine:
///
/// 1. perform the DNS change via `DNSManager`
/// 2. persist the active / last-applied profile
/// 3. append a connection-log entry
/// 4. refresh widgets & Control Center so they stay truthful
@MainActor
enum DNSApplyService {
    static func apply(_ profile: DNSProfile) async throws {
        try await apply(profile, using: DNSManager.shared)
    }

    static func apply(_ profile: DNSProfile, using manager: DNSApplying) async throws {
        try await manager.applyProfile(profile)
        await PersistenceManager.shared.saveActiveProfileID(profile.id)
        await PersistenceManager.shared.saveLastAppliedProfileID(profile.id)
        await appendLog(ConnectionLogEntry(
            profileName: profile.name,
            servers: profile.servers,
            action: .applied
        ))
        reloadWidgets()
    }

    static func disable() async throws {
        try await disable(using: DNSManager.shared)
    }

    static func disable(using manager: DNSApplying) async throws {
        try await manager.disableCustomDNS()
        await PersistenceManager.shared.saveActiveProfileID(nil)
        await appendLog(ConnectionLogEntry(
            profileName: "System Default",
            servers: [],
            action: .removed
        ))
        reloadWidgets()
    }

    private static func appendLog(_ entry: ConnectionLogEntry) async {
        var log = await PersistenceManager.shared.loadConnectionLog()
        log.append(entry)
        await PersistenceManager.shared.saveConnectionLog(log)
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
