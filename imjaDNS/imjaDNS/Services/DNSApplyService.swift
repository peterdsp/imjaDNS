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
    func status() async -> DNSStatus
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
        // Saving a profile does not put it in effect — the user still has to
        // enable it in Settings. Ask the system rather than assuming, so the
        // widget doesn't claim protection the device isn't providing.
        let isActive = await manager.status() == .active
        WidgetStateStore.save(WidgetState(
            isActive: isActive,
            profileName: profile.name,
            categoryIcon: profile.category.icon,
            gradient: profile.category.gradient,
            latencyMs: nil,
            updatedAt: Date()
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
        WidgetStateStore.save(WidgetState(
            isActive: false,
            profileName: WidgetState.systemDefault.profileName,
            categoryIcon: WidgetState.systemDefault.categoryIcon,
            gradient: WidgetState.systemDefault.gradient,
            latencyMs: nil,
            updatedAt: Date()
        ))
        reloadWidgets()
    }

    /// Installs a profile as **cellular-only** via on-demand rules: iOS applies
    /// it on mobile data and turns it off on Wi-Fi, enforced in the background.
    static func applyCellularOnly(_ profile: DNSProfile) async throws {
        try await DNSManager.shared.applyProfile(profile, condition: .cellularOnly)
        await PersistenceManager.shared.saveActiveProfileID(profile.id)
        await PersistenceManager.shared.saveLastAppliedProfileID(profile.id)
        await appendLog(ConnectionLogEntry(
            profileName: "\(profile.name) · cellular",
            servers: profile.servers,
            action: .applied
        ))
        let isActive = await DNSManager.shared.status() == .active
        WidgetStateStore.save(WidgetState(
            isActive: isActive,
            profileName: profile.name,
            categoryIcon: profile.category.icon,
            gradient: profile.category.gradient,
            latencyMs: nil,
            updatedAt: Date()
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
        Task { await PhoneConnectivityManager.shared.syncStateToWatch() }
    }
}
