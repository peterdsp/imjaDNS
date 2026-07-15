import Foundation

/// Time window for latency analysis.
enum TimeWindow: String, CaseIterable, Identifiable, Equatable {
    case day = "24h"
    case week = "7d"
    case month = "30d"

    var id: String { rawValue }
    var title: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .day: return 24 * 60 * 60
        case .week: return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }
}

/// Pure aggregation over persisted speed-test history. No I/O, no dates of its
/// own beyond the injectable `now`, so it's fully unit-testable.
///
/// Note: `SpeedTestResult` records only successful probes, so a reliability /
/// failure rate isn't derivable here — we intentionally don't report one.
enum LatencyAnalytics {
    struct ProviderStat: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let medianMs: Double
        let bestMs: Double
        let sampleCount: Int
    }

    struct LatencyPoint: Equatable {
        let date: Date
        let ms: Double
    }

    struct ProviderSeries: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let points: [LatencyPoint]
    }

    static func filter(_ results: [SpeedTestResult], window: TimeWindow, now: Date) -> [SpeedTestResult] {
        let cutoff = now.addingTimeInterval(-window.interval)
        return results.filter { $0.timestamp >= cutoff }
    }

    /// Leaderboard: one stat per provider in the window, fastest median first.
    static func providerStats(from results: [SpeedTestResult], window: TimeWindow, now: Date) -> [ProviderStat] {
        let recent = filter(results, window: window, now: now)
        let grouped = Dictionary(grouping: recent, by: \.profileName)
        return grouped.map { name, entries in
            let values = entries.map(\.latencyMs).sorted()
            return ProviderStat(
                name: name,
                medianMs: median(ofSorted: values),
                bestMs: values.first ?? 0,
                sampleCount: values.count
            )
        }
        .sorted { $0.medianMs < $1.medianMs }
    }

    /// Time series per provider for charting, chronological within each provider.
    static func series(from results: [SpeedTestResult], window: TimeWindow, now: Date) -> [ProviderSeries] {
        let recent = filter(results, window: window, now: now)
        let grouped = Dictionary(grouping: recent, by: \.profileName)
        return grouped.map { name, entries in
            let points = entries
                .sorted { $0.timestamp < $1.timestamp }
                .map { LatencyPoint(date: $0.timestamp, ms: $0.latencyMs) }
            return ProviderSeries(name: name, points: points)
        }
        .sorted { $0.name < $1.name }
    }

    static func median(ofSorted values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let n = values.count
        if n % 2 == 1 { return values[n / 2] }
        return (values[n / 2 - 1] + values[n / 2]) / 2
    }
}
