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

// MARK: - Browsable scenario catalog

/// A real-world usage scenario the user can browse and tap into, with the
/// bandwidth/latency it needs. Ratings are derived uniformly from these
/// thresholds so the detail view can show "you have X, this needs Y".
struct Scenario: Identifiable, Equatable, Sendable {
    let id: String
    let icon: String
    let name: String
    let detail: String
    /// One-line human requirement, e.g. "≈25 Mbps download".
    let requirement: String
    let needDown: Double   // Mbps for a smooth experience
    let tightDown: Double  // Mbps below which it struggles
    let needUp: Double     // Mbps up needed (0 when not upload-bound)
    let maxPing: Double    // ms ceiling (.infinity when latency-insensitive)
    let maxJitter: Double  // ms ceiling (.infinity when jitter-insensitive)

    func rating(down d: Double, up u: Double, ping p: Double, jitter j: Double) -> SpeedRating {
        let smooth = d >= needDown && u >= needUp && p <= maxPing && j <= maxJitter
        if smooth { return .smooth }
        let tight = d >= tightDown && u >= needUp * 0.5 && p <= maxPing * 1.5
        return tight ? .tight : .struggles
    }
}

extension InternetScenarios {
    private static let inf = Double.infinity

    /// The full, browsable catalog — visible before any test so users can see
    /// what their connection would need for each activity.
    static let catalog: [Scenario] = [
        Scenario(id: "web", icon: "globe", name: "Web & social", detail: "Browsing, chat, email",
                 requirement: "≈5–25 Mbps down", needDown: 25, tightDown: 5, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "shortvideo", icon: "play.rectangle", name: "Social video", detail: "TikTok, Reels, YouTube Shorts",
                 requirement: "≈10 Mbps down", needDown: 10, tightDown: 3, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "hd", icon: "tv", name: "HD streaming", detail: "1080p on one screen",
                 requirement: "≈15 Mbps down", needDown: 15, tightDown: 5, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "uhd", icon: "4k.tv", name: "Netflix / YouTube 4K", detail: "Ultra-HD on one screen",
                 requirement: "≈25–40 Mbps down", needDown: 40, tightDown: 25, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "eightk", icon: "tv.fill", name: "8K streaming", detail: "Next-gen ultra-HD",
                 requirement: "≈100 Mbps down", needDown: 100, tightDown: 50, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "iptv", icon: "antenna.radiowaves.left.and.right", name: "IPTV", detail: "Live TV over the internet",
                 requirement: "≈25 Mbps down, steady", needDown: 25, tightDown: 15, needUp: 0, maxPing: inf, maxJitter: 30),
        Scenario(id: "cloudgaming", icon: "gamecontroller", name: "Cloud gaming", detail: "GeForce NOW, Xbox Cloud",
                 requirement: "≥25 Mbps down, ping < 40 ms", needDown: 25, tightDown: 12, needUp: 0, maxPing: 40, maxJitter: 20),
        Scenario(id: "onlinegaming", icon: "gamecontroller.fill", name: "Online gaming", detail: "Competitive multiplayer",
                 requirement: "Low ping < 50 ms, steady", needDown: 5, tightDown: 3, needUp: 2, maxPing: 50, maxJitter: 15),
        Scenario(id: "calls", icon: "video", name: "Video calls", detail: "Zoom, FaceTime, Meet (HD)",
                 requirement: "≈8 Mbps down / 3 up", needDown: 8, tightDown: 3, needUp: 3, maxPing: 150, maxJitter: 40),
        Scenario(id: "cameras", icon: "video.fill", name: "Security cameras", detail: "Uploading several feeds",
                 requirement: "≈10 Mbps upload", needDown: 5, tightDown: 3, needUp: 10, maxPing: inf, maxJitter: inf),
        Scenario(id: "backup", icon: "arrow.up.doc", name: "Cloud backup", detail: "Photo & file sync",
                 requirement: "≈20 Mbps upload", needDown: 5, tightDown: 3, needUp: 20, maxPing: inf, maxJitter: inf),
        Scenario(id: "download", icon: "arrow.down.circle", name: "Big downloads", detail: "Games & system updates",
                 requirement: "The more down, the faster", needDown: 100, tightDown: 40, needUp: 0, maxPing: inf, maxJitter: inf),
        Scenario(id: "combo", icon: "popcorn", name: "Movie night + gaming", detail: "4K stream while someone games",
                 requirement: "≈80 Mbps down, ping < 50", needDown: 80, tightDown: 45, needUp: 0, maxPing: 50, maxJitter: 30),
        Scenario(id: "smart", icon: "house", name: "Full smart home", detail: "Many 4K screens, cameras & gaming",
                 requirement: "≥150 Mbps down / 20 up", needDown: 150, tightDown: 80, needUp: 20, maxPing: inf, maxJitter: inf)
    ]
}
