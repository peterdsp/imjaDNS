import Testing
import Foundation
@testable import imjaDNS

// MARK: - Mock

@MainActor
final class MockDNSApplier: DNSApplying {
    private(set) var appliedProfiles: [DNSProfile] = []
    private(set) var disableCount = 0
    var applyError: Error?

    func applyProfile(_ profile: DNSProfile) async throws {
        if let applyError { throw applyError }
        appliedProfiles.append(profile)
    }

    func disableCustomDNS() async throws {
        disableCount += 1
    }

    func testProfileLatency(_ profile: DNSProfile) async -> Double? { 12.3 }
    func currentServersDisplay() async -> String { "1.1.1.1" }
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
}
