import Testing
import Foundation
@testable import imjaDNS

struct InternetScenariosTests {
    private func rating(_ id: String, down: Double, up: Double, ping: Double, jitter: Double) -> SpeedRating {
        InternetScenarios.evaluate(down: down, up: up, ping: ping, jitter: jitter)
            .first { $0.id == id }!.rating
    }

    @Test func fastFiberIsAllSmooth() {
        let results = InternetScenarios.evaluate(down: 800, up: 400, ping: 10, jitter: 2)
        #expect(results.count == 8)
        #expect(results.allSatisfy { $0.rating == .smooth })
    }

    @Test func highLatencyPenalizesGamingAndIPTV() {
        // Plenty of bandwidth but poor ping/jitter.
        #expect(rating("gaming", down: 500, up: 100, ping: 90, jitter: 40) == .struggles)
        #expect(rating("iptv", down: 500, up: 100, ping: 90, jitter: 40) == .tight) // jitter ≥ 30 → not smooth
        #expect(rating("web", down: 500, up: 100, ping: 90, jitter: 40) == .smooth)
    }

    @Test func lowUploadHurtsCameras() {
        #expect(rating("cameras", down: 300, up: 2, ping: 20, jitter: 5) == .struggles)
        #expect(rating("cameras", down: 300, up: 6, ping: 20, jitter: 5) == .tight)
        #expect(rating("cameras", down: 300, up: 20, ping: 20, jitter: 5) == .smooth)
    }

    @Test func slowDSLStruggles() {
        #expect(rating("uhd", down: 8, up: 1, ping: 30, jitter: 5) == .struggles)
        #expect(rating("hd", down: 8, up: 1, ping: 30, jitter: 5) == .tight)
        #expect(rating("smart", down: 8, up: 1, ping: 30, jitter: 5) == .struggles)
    }
}
