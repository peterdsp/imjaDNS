import Foundation

enum DNSProfileCatalog {
    static let builtIn: [DNSProfile] = [
        // MARK: - Privacy
        DNSProfile(
            name: "Cloudflare",
            servers: ["1.1.1.1", "1.0.0.1"],
            category: .privacy,
            protocolType: .doh,
            description: "Fast, privacy-first DNS. Cloudflare doesn't sell your data and wipes logs within 24 hours.",
            website: "https://1.1.1.1",
            isBuiltIn: true,
            dohURL: "https://cloudflare-dns.com/dns-query",
            dotHostname: "one.one.one.one"
        ),
        DNSProfile(
            name: "Quad9",
            servers: ["9.9.9.9", "149.112.112.112"],
            category: .privacy,
            protocolType: .doh,
            description: "Swiss-based non-profit. Blocks known malicious domains while respecting your privacy.",
            website: "https://quad9.net",
            isBuiltIn: true,
            dohURL: "https://dns.quad9.net/dns-query",
            dotHostname: "dns.quad9.net"
        ),
        DNSProfile(
            name: "Mullvad DNS",
            servers: ["194.242.2.2"],
            category: .privacy,
            protocolType: .doh,
            description: "No-logging DNS from the trusted VPN provider. No filtering, pure privacy.",
            website: "https://mullvad.net/en/help/dns-over-https-and-dns-over-tls",
            isBuiltIn: true,
            dohURL: "https://dns.mullvad.net/dns-query",
            dotHostname: "dns.mullvad.net"
        ),

        // MARK: - Speed
        DNSProfile(
            name: "Google DNS",
            servers: ["8.8.8.8", "8.8.4.4"],
            category: .speed,
            protocolType: .doh,
            description: "Google's global DNS infrastructure. Optimized for speed with massive anycast network.",
            website: "https://developers.google.com/speed/public-dns",
            isBuiltIn: true,
            dohURL: "https://dns.google/dns-query",
            dotHostname: "dns.google"
        ),
        DNSProfile(
            name: "NextDNS",
            servers: ["45.90.28.0", "45.90.30.0"],
            category: .speed,
            protocolType: .doh,
            description: "Customizable DNS with analytics. Low-latency global network with optional filtering.",
            website: "https://nextdns.io",
            isBuiltIn: true,
            dohURL: "https://dns.nextdns.io",
            dotHostname: "dns.nextdns.io"
        ),
        DNSProfile(
            name: "Cloudflare WARP",
            servers: ["1.1.1.2", "1.0.0.2"],
            category: .speed,
            protocolType: .doh,
            description: "Cloudflare with malware blocking. Same speed as 1.1.1.1 plus threat protection.",
            website: "https://1.1.1.1",
            isBuiltIn: true,
            dohURL: "https://security.cloudflare-dns.com/dns-query",
            dotHostname: "security.cloudflare-dns.com"
        ),

        // MARK: - Family Safe
        DNSProfile(
            name: "Cloudflare Family",
            servers: ["1.1.1.3", "1.0.0.3"],
            category: .familySafe,
            protocolType: .doh,
            description: "Blocks malware and adult content. Safe browsing for the whole family.",
            website: "https://1.1.1.1/family",
            isBuiltIn: true,
            dohURL: "https://family.cloudflare-dns.com/dns-query",
            dotHostname: "family.cloudflare-dns.com"
        ),
        DNSProfile(
            name: "CleanBrowsing Family",
            servers: ["185.228.168.168", "185.228.169.168"],
            category: .familySafe,
            protocolType: .doh,
            description: "Strict family filter. Blocks adult content, proxies, and mixed content on Google/Bing.",
            website: "https://cleanbrowsing.org",
            isBuiltIn: true,
            dohURL: "https://doh.cleanbrowsing.org/doh/family-filter",
            dotHostname: "family-filter-dns.cleanbrowsing.org"
        ),
        DNSProfile(
            name: "OpenDNS Family",
            servers: ["208.67.222.123", "208.67.220.123"],
            category: .familySafe,
            protocolType: .plain,
            description: "Cisco's family shield. Pre-configured to block adult content across all devices.",
            website: "https://www.opendns.com/setupguide/#familyshield",
            isBuiltIn: true
        ),

        // MARK: - Security
        DNSProfile(
            name: "AdGuard DNS",
            servers: ["94.140.14.14", "94.140.15.15"],
            category: .security,
            protocolType: .doh,
            description: "Blocks ads, trackers, and malware at the DNS level. Faster browsing, fewer distractions.",
            website: "https://adguard-dns.io",
            isBuiltIn: true,
            dohURL: "https://dns.adguard-dns.com/dns-query",
            dotHostname: "dns.adguard-dns.com"
        ),
        DNSProfile(
            name: "Control D",
            servers: ["76.76.2.0", "76.76.10.0"],
            category: .security,
            protocolType: .doh,
            description: "Customizable DNS with malware and ad blocking. Fine-grained control over what gets blocked.",
            website: "https://controld.com",
            isBuiltIn: true,
            dohURL: "https://freedns.controld.com/p0",
            dotHostname: "p0.freedns.controld.com"
        ),
        DNSProfile(
            name: "Quad9 + ECS",
            servers: ["9.9.9.11", "149.112.112.11"],
            category: .security,
            protocolType: .doh,
            description: "Quad9 with threat blocking and EDNS Client Subnet for better CDN routing.",
            website: "https://quad9.net",
            isBuiltIn: true,
            dohURL: "https://dns11.quad9.net/dns-query",
            dotHostname: "dns11.quad9.net"
        ),

        // MARK: - Gaming
        DNSProfile(
            name: "Google Low-Latency",
            servers: ["8.8.8.8", "8.8.4.4"],
            category: .gaming,
            protocolType: .plain,
            description: "Plain DNS for minimal overhead. Best for competitive gaming where every millisecond counts.",
            website: "https://developers.google.com/speed/public-dns",
            isBuiltIn: true
        ),
        DNSProfile(
            name: "Level3 DNS",
            servers: ["4.2.2.1", "4.2.2.2"],
            category: .gaming,
            protocolType: .plain,
            description: "Tier-1 backbone provider DNS. Minimal hops, maximum uptime, no filtering overhead.",
            isBuiltIn: true
        ),
        DNSProfile(
            name: "OpenDNS",
            servers: ["208.67.222.222", "208.67.220.220"],
            category: .gaming,
            protocolType: .plain,
            description: "Cisco's reliable DNS. Global infrastructure with smart caching for faster game connections.",
            website: "https://www.opendns.com",
            isBuiltIn: true
        ),
    ]

    static func profiles(for category: DNSCategory) -> [DNSProfile] {
        builtIn.filter { $0.category == category }
    }
}
