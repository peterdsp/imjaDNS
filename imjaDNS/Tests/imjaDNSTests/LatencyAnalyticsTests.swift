import Testing
import Foundation
@testable import imjaDNS

struct LatencyAnalyticsTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func result(_ name: String, _ ms: Double, ageHours: Double) -> SpeedTestResult {
        SpeedTestResult(
            profileName: name,
            server: "1.1.1.1",
            latencyMs: ms,
            timestamp: now.addingTimeInterval(-ageHours * 3600)
        )
    }

    @Test func medianOddAndEven() {
        #expect(LatencyAnalytics.median(ofSorted: [10, 20, 30]) == 20)
        #expect(LatencyAnalytics.median(ofSorted: [10, 20, 30, 40]) == 25)
        #expect(LatencyAnalytics.median(ofSorted: []) == 0)
    }

    @Test func windowFiltersOldResults() {
        let results = [
            result("A", 10, ageHours: 1),    // within 24h
            result("A", 50, ageHours: 48)    // outside 24h
        ]
        let recent = LatencyAnalytics.filter(results, window: .day, now: now)
        #expect(recent.count == 1)
        #expect(recent.first?.latencyMs == 10)
    }

    @Test func leaderboardSortedByMedianFastestFirst() {
        let results = [
            result("Slow", 100, ageHours: 1),
            result("Slow", 120, ageHours: 2),
            result("Fast", 10, ageHours: 1),
            result("Fast", 20, ageHours: 2)
        ]
        let stats = LatencyAnalytics.providerStats(from: results, window: .week, now: now)
        #expect(stats.count == 2)
        #expect(stats.first?.name == "Fast")
        #expect(stats.first?.medianMs == 15)
        #expect(stats.first?.bestMs == 10)
        #expect(stats.first?.sampleCount == 2)
        #expect(stats.last?.name == "Slow")
    }

    @Test func seriesIsChronologicalPerProvider() {
        let results = [
            result("A", 30, ageHours: 1),   // newer
            result("A", 10, ageHours: 5)    // older
        ]
        let series = LatencyAnalytics.series(from: results, window: .week, now: now)
        #expect(series.count == 1)
        let points = series.first?.points ?? []
        #expect(points.count == 2)
        #expect(points.first?.ms == 10)  // oldest first
        #expect(points.last?.ms == 30)
    }
}
