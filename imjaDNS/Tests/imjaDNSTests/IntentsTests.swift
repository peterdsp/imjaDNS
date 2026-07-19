import Testing
import Foundation
@testable import imjaDNS

// MARK: - Mock

@MainActor
final class MockDNSApplier: DNSApplying {
    private(set) var appliedProfiles: [DNSProfile] = []
    private(set) var disableCount = 0
    var applyError: Error?
    /// What the system reports after a profile is applied. Defaults to the
    /// case a first-time user hits: installed, but not yet enabled in Settings.
    var statusAfterApply: DNSStatus = .installedNotEnabled

    func applyProfile(_ profile: DNSProfile) async throws {
        if let applyError { throw applyError }
        appliedProfiles.append(profile)
    }

    func disableCustomDNS() async throws {
        disableCount += 1
    }

    func testProfileLatency(_ profile: DNSProfile) async -> Double? { 12.3 }
    func currentServersDisplay() async -> String { "1.1.1.1" }
    func status() async -> DNSStatus { appliedProfiles.isEmpty ? .off : statusAfterApply }
}

// MARK: - ProfileEntity mapping

struct ProfileEntityTests {
    @Test func mapsFromProfile() {
        let profile = DNSProfile(name: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"])
        let entity = ProfileEntity(profile)
        #expect(entity.id == profile.id)
        #expect(entity.name == "Cloudflare")
        #expect(entity.serversDisplay == "1.1.1.1, 1.0.0.1")
    }
}

// MARK: - DNSApplyService seam

/// Serialized: every case here writes the process-wide `WidgetStateStore`, so
/// running them in parallel would let one case read another's state.
@Suite(.serialized)
@MainActor
struct DNSApplyServiceTests {
    @Test func applyForwardsToManager() async throws {
        let mock = MockDNSApplier()
        let profile = DNSProfile(name: "Quad9", servers: ["9.9.9.9"])
        try await DNSApplyService.apply(profile, using: mock)
        #expect(mock.appliedProfiles.count == 1)
        #expect(mock.appliedProfiles.first?.id == profile.id)
    }

    @Test func disableForwardsToManager() async throws {
        let mock = MockDNSApplier()
        try await DNSApplyService.disable(using: mock)
        #expect(mock.disableCount == 1)
    }

    @Test func applyPropagatesError() async {
        let mock = MockDNSApplier()
        mock.applyError = DNSError.noServersProvided
        let profile = DNSProfile(name: "Bad", servers: [])
        await #expect(throws: DNSError.self) {
            try await DNSApplyService.apply(profile, using: mock)
        }
    }

    /// Applying a profile the user has not enabled in Settings must not leave
    /// the widget claiming protection the device isn't providing.
    @Test func widgetIsInactiveWhenProfileInstalledButNotEnabled() async throws {
        let mock = MockDNSApplier()
        mock.statusAfterApply = .installedNotEnabled
        try await DNSApplyService.apply(DNSProfile(name: "Quad9", servers: ["9.9.9.9"]), using: mock)
        #expect(WidgetStateStore.load().isActive == false)
    }

    @Test func widgetIsActiveOnceTheProfileIsEnabled() async throws {
        let mock = MockDNSApplier()
        mock.statusAfterApply = .active
        try await DNSApplyService.apply(DNSProfile(name: "Quad9", servers: ["9.9.9.9"]), using: mock)
        #expect(WidgetStateStore.load().isActive == true)
    }
}
