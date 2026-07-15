import Testing
import Foundation
@testable import imjaDNS

struct ProfileTransferTests {
    @Test func roundTripEncodeDecode() throws {
        let profiles = [
            DNSProfile(name: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"], protocolType: .doh, dohURL: "https://cloudflare-dns.com/dns-query"),
            DNSProfile(name: "Quad9", servers: ["9.9.9.9"])
        ]
        let data = try ProfileTransfer.encode(profiles)
        let decoded = try ProfileTransfer.decode(data)
        #expect(decoded.count == 2)
        #expect(decoded.first?.name == "Cloudflare")
        #expect(decoded.first?.servers == ["1.1.1.1", "1.0.0.1"])
    }

    @Test func sanitizeReassignsIdsAndClearsFlags() {
        let original = DNSProfile(name: "Mine", servers: ["8.8.8.8"], isFavorite: true, isBuiltIn: true)
        let cleaned = ProfileTransfer.sanitize([original])
        #expect(cleaned.count == 1)
        #expect(cleaned[0].id != original.id)      // fresh id
        #expect(cleaned[0].isFavorite == false)
        #expect(cleaned[0].isBuiltIn == false)
        #expect(cleaned[0].name == "Mine")
    }

    @Test func sanitizeDropsInvalid() {
        let bad = DNSProfile(name: "Bad", servers: ["not-an-ip"], protocolType: .plain)
        let goodPlain = DNSProfile(name: "Good", servers: ["1.1.1.1"], protocolType: .plain)
        let goodDoH = DNSProfile(name: "DoH", servers: [], protocolType: .doh, dohURL: "https://dns.example/dns-query")
        let cleaned = ProfileTransfer.sanitize([bad, goodPlain, goodDoH])
        #expect(cleaned.count == 2)
        #expect(Set(cleaned.map(\.name)) == ["Good", "DoH"])
    }

    @Test func sanitizeEmptyNameGetsFallback() {
        let noName = DNSProfile(name: "", servers: ["1.1.1.1"])
        let cleaned = ProfileTransfer.sanitize([noName])
        #expect(cleaned.first?.name == "Imported profile")
    }
}
