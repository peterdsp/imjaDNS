import Foundation

enum SpeedRating: String, Equatable, Sendable {
    case smooth, tight, struggles
}

struct ScenarioResult: Identifiable, Equatable, Sendable {
    let id: String
    let icon: String
    let name: String
    let detail: String
    let rating: SpeedRating
}

/// Rates real-world usage scenarios from measured bandwidth/latency. Same
/// thresholds as the website. Pure and unit-tested.
enum InternetScenarios {
    private static func rate(_ v: Int) -> SpeedRating { v == 2 ? .smooth : v == 1 ? .tight : .struggles }

    static func evaluate(down d: Double, up u: Double, ping p: Double, jitter j: Double) -> [ScenarioResult] {
        [
            ScenarioResult(id: "web", icon: "globe", name: "Web & social", detail: "Browsing, chat, email",
                           rating: rate(d >= 25 ? 2 : d >= 5 ? 1 : 0)),
            ScenarioResult(id: "hd", icon: "tv", name: "HD streaming", detail: "1080p on one screen",
                           rating: rate(d >= 15 ? 2 : d >= 5 ? 1 : 0)),
            ScenarioResult(id: "uhd", icon: "4k.tv", name: "Netflix 4K", detail: "Ultra-HD streaming",
                           rating: rate(d >= 40 ? 2 : d >= 25 ? 1 : 0)),
            ScenarioResult(id: "iptv", icon: "antenna.radiowaves.left.and.right", name: "IPTV", detail: "Live TV over the internet",
                           rating: rate((d >= 25 && j < 30) ? 2 : d >= 15 ? 1 : 0)),
            ScenarioResult(id: "gaming", icon: "gamecontroller", name: "Cloud gaming", detail: "Latency-sensitive play",
                           rating: rate((p < 40 && d >= 25) ? 2 : (p < 80 && d >= 12) ? 1 : 0)),
            ScenarioResult(id: "cameras", icon: "video", name: "Security cameras", detail: "Uploading several feeds",
                           rating: rate(u >= 10 ? 2 : u >= 4 ? 1 : 0)),
            ScenarioResult(id: "combo", icon: "popcorn", name: "Movie night + gaming", detail: "4K stream while someone games",
                           rating: rate((d >= 80 && p < 50) ? 2 : (d >= 45 && p < 80) ? 1 : 0)),
            ScenarioResult(id: "smart", icon: "house", name: "Full smart home", detail: "Many 4K screens, cameras & gaming",
                           rating: rate((d >= 150 && u >= 20) ? 2 : (d >= 80 && u >= 10) ? 1 : 0))
        ]
    }
}
