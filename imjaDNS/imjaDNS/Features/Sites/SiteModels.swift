import Foundation

/// A website the user can check for reachability through their current DNS.
struct Website: Identifiable, Codable, Equatable, Sendable {
    var id: String { domain }
    let name: String
    let domain: String
    let category: SiteCategory
    var isCustom: Bool = false
}

enum SiteCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case streaming, social, gaming, shopping, news, tools, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .streaming: return "Streaming"
        case .social: return "Social"
        case .gaming: return "Gaming"
        case .shopping: return "Shopping"
        case .news: return "News"
        case .tools: return "Tools"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .streaming: return "play.tv"
        case .social: return "bubble.left.and.bubble.right"
        case .gaming: return "gamecontroller"
        case .shopping: return "cart"
        case .news: return "newspaper"
        case .tools: return "wrench.and.screwdriver"
        case .custom: return "star"
        }
    }
}

/// The outcome of checking one site: DNS resolution AND HTTP reachability,
/// both exercised through whatever DNS is currently active.
struct SiteCheckResult: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case idle, checking, done }
    var phase: Phase = .idle

    // DNS resolution
    var resolvedIP: String?
    var dnsMs: Double?
    var resolved: Bool { resolvedIP != nil }

    // HTTP reachability
    var reachable: Bool?
    var httpStatus: Int?
    var reachMs: Double?

    var checkedAt: Date?

    /// A one-word verdict combining both signals.
    enum Verdict { case ok, blocked, unreachable, unresolved, unknown }
    var verdict: Verdict {
        guard phase == .done else { return .unknown }
        if resolvedIP == nil { return .unresolved }
        // Resolved to a null/blocked address is a common DNS-filtering tell.
        if let ip = resolvedIP, ip == "0.0.0.0" || ip == "::" { return .blocked }
        if reachable == true { return .ok }
        return .unreachable
    }
}

enum SiteDirectory {
    /// A curated starter set. Users add their own via custom sites.
    static let builtIn: [Website] = [
        // Streaming
        Website(name: "Netflix", domain: "netflix.com", category: .streaming),
        Website(name: "YouTube", domain: "youtube.com", category: .streaming),
        Website(name: "Disney+", domain: "disneyplus.com", category: .streaming),
        Website(name: "Twitch", domain: "twitch.tv", category: .streaming),
        Website(name: "Spotify", domain: "spotify.com", category: .streaming),
        Website(name: "Prime Video", domain: "primevideo.com", category: .streaming),
        // Social
        Website(name: "Instagram", domain: "instagram.com", category: .social),
        Website(name: "TikTok", domain: "tiktok.com", category: .social),
        Website(name: "X (Twitter)", domain: "x.com", category: .social),
        Website(name: "Facebook", domain: "facebook.com", category: .social),
        Website(name: "Reddit", domain: "reddit.com", category: .social),
        Website(name: "WhatsApp", domain: "whatsapp.com", category: .social),
        Website(name: "Telegram", domain: "telegram.org", category: .social),
        // Gaming
        Website(name: "Steam", domain: "steampowered.com", category: .gaming),
        Website(name: "Epic Games", domain: "epicgames.com", category: .gaming),
        Website(name: "Xbox", domain: "xbox.com", category: .gaming),
        Website(name: "PlayStation", domain: "playstation.com", category: .gaming),
        Website(name: "Discord", domain: "discord.com", category: .gaming),
        // Shopping
        Website(name: "Amazon", domain: "amazon.com", category: .shopping),
        Website(name: "eBay", domain: "ebay.com", category: .shopping),
        Website(name: "AliExpress", domain: "aliexpress.com", category: .shopping),
        // News
        Website(name: "BBC", domain: "bbc.com", category: .news),
        Website(name: "CNN", domain: "cnn.com", category: .news),
        Website(name: "The Guardian", domain: "theguardian.com", category: .news),
        // Tools
        Website(name: "Google", domain: "google.com", category: .tools),
        Website(name: "Wikipedia", domain: "wikipedia.org", category: .tools),
        Website(name: "GitHub", domain: "github.com", category: .tools),
        Website(name: "ChatGPT", domain: "chat.openai.com", category: .tools),
        Website(name: "Cloudflare", domain: "cloudflare.com", category: .tools)
    ]
}
