import Testing
import Foundation
@testable import imjaDNS

struct DiagnosticsTests {
    private func response(rcode: Int, rtt: Double = 20, answers: Int = 1) -> DNSLatencyTester.DNSResponse {
        DNSLatencyTester.DNSResponse(rtt: rtt, rcode: rcode, answerCount: answers)
    }

    // MARK: - Encryption

    @Test func encryptionByProtocol() {
        let doh = DNSProfile(name: "CF", servers: ["1.1.1.1"], protocolType: .doh)
        let dot = DNSProfile(name: "CF", servers: ["1.1.1.1"], protocolType: .dot)
        let plain = DNSProfile(name: "L3", servers: ["4.2.2.1"], protocolType: .plain)
        #expect(DNSDiagnostics.encryptionCheck(doh).status == .pass)
        #expect(DNSDiagnostics.encryptionCheck(dot).status == .pass)
        #expect(DNSDiagnostics.encryptionCheck(plain).status == .warn)
        #expect(DNSDiagnostics.encryptionCheck(nil).status == .warn)
    }

    // MARK: - Reachability

    @Test func reachabilityInterpretation() {
        #expect(DNSDiagnostics.interpretReachability(nil, server: "1.1.1.1").status == .fail)
        #expect(DNSDiagnostics.interpretReachability(response(rcode: 0), server: "1.1.1.1").status == .pass)
        #expect(DNSDiagnostics.interpretReachability(response(rcode: 3), server: "1.1.1.1").status == .warn)
    }

    // MARK: - DNSSEC

    @Test func dnssecInterpretation() {
        #expect(DNSDiagnostics.interpretDNSSEC(response(rcode: 2)).status == .pass)  // SERVFAIL → validates
        #expect(DNSDiagnostics.interpretDNSSEC(response(rcode: 0)).status == .warn)  // resolved broken domain
        #expect(DNSDiagnostics.interpretDNSSEC(response(rcode: 5)).status == .unknown)
        #expect(DNSDiagnostics.interpretDNSSEC(nil).status == .unknown)
    }

    // MARK: - Overall

    @Test func combineSeverity() {
        #expect(DNSDiagnostics.combine([.pass, .pass, .pass]) == .pass)
        #expect(DNSDiagnostics.combine([.pass, .warn, .pass]) == .warn)
        #expect(DNSDiagnostics.combine([.pass, .unknown, .pass]) == .warn)
        #expect(DNSDiagnostics.combine([.warn, .fail, .pass]) == .fail)
    }

    // MARK: - Response parsing

    @Test func parseResponseReadsHeader() {
        // 12-byte header: id=0x1234, flags=0x8182 (QR set, RCODE=2), QD=1, AN=1
        var data = Data([0x12, 0x34, 0x81, 0x82, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x00])
        let parsed = DNSLatencyTester.parseResponse(data, rtt: 15)
        #expect(parsed?.rcode == 2)
        #expect(parsed?.answerCount == 1)
        #expect(parsed?.rtt == 15)
    }

    @Test func parseResponseRejectsQuery() {
        // QR bit unset (0x0100) → not a response
        let data = Data([0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(DNSLatencyTester.parseResponse(data, rtt: 5) == nil)
    }

    @Test func parseResponseRejectsShort() {
        #expect(DNSLatencyTester.parseResponse(Data([0x00, 0x01]), rtt: 5) == nil)
    }
}
