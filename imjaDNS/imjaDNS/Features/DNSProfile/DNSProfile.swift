import Foundation

enum DNSCategory: String, Codable, CaseIterable, Identifiable {
    case privacy = "Privacy"
    case speed = "Speed"
    case familySafe = "Family Safe"
    case security = "Security"
    case gaming = "Gaming"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .privacy: return "eye.slash.fill"
        case .speed: return "bolt.fill"
        case .familySafe: return "figure.2.and.child.holdinghands"
        case .security: return "shield.checkered"
        case .gaming: return "gamecontroller.fill"
        case .custom: return "wrench.and.screwdriver.fill"
        }
    }

    var gradient: [String] {
        switch self {
        case .privacy: return ["#6C63FF", "#3F37C9"]
        case .speed: return ["#00D2FF", "#3A7BD5"]
        case .familySafe: return ["#F857A6", "#FF5858"]
        case .security: return ["#11998E", "#38EF7D"]
        case .gaming: return ["#FC466B", "#3F5EFB"]
        case .custom: return ["#F2994A", "#F2C94C"]
        }
    }
}

enum DNSProtocolType: String, Codable, CaseIterable {
    case plain = "DNS"
    case doh = "DoH"
    case dot = "DoT"

    var displayName: String {
        switch self {
        case .plain: return "Standard DNS"
        case .doh: return "DNS over HTTPS"
        case .dot: return "DNS over TLS"
        }
    }
}

struct DNSProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var servers: [String]
    var category: DNSCategory
    var protocolType: DNSProtocolType
    var description: String
    var website: String?
    var isFavorite: Bool
    var isBuiltIn: Bool
    var dohURL: String?
    var dotHostname: String?

    var primaryServer: String { servers.first ?? "" }

    var serversDisplay: String { servers.joined(separator: ", ") }

    init(
        id: UUID = UUID(),
        name: String,
        servers: [String],
        category: DNSCategory = .custom,
        protocolType: DNSProtocolType = .plain,
        description: String = "",
        website: String? = nil,
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        dohURL: String? = nil,
        dotHostname: String? = nil
    ) {
        self.id = id
        self.name = name
        self.servers = servers
        self.category = category
        self.protocolType = protocolType
        self.description = description
        self.website = website
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.dohURL = dohURL
        self.dotHostname = dotHostname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        category = (try? container.decode(DNSCategory.self, forKey: .category)) ?? .custom
        protocolType = (try? container.decode(DNSProtocolType.self, forKey: .protocolType)) ?? .plain
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        website = try? container.decode(String.self, forKey: .website)
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
        isBuiltIn = (try? container.decode(Bool.self, forKey: .isBuiltIn)) ?? false
        dohURL = try? container.decode(String.self, forKey: .dohURL)
        dotHostname = try? container.decode(String.self, forKey: .dotHostname)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()

        if let serversArray = try? container.decode([String].self, forKey: .servers) {
            servers = serversArray
        } else if let serversString = try? container.decode(String.self, forKey: .servers) {
            servers = serversString
                .components(separatedBy: CharacterSet(charactersIn: ", "))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            servers = []
        }
    }
}

struct ConnectionLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let profileName: String
    let servers: [String]
    let timestamp: Date
    let action: LogAction
    let latencyMs: Double?

    enum LogAction: String, Codable {
        case applied = "Applied"
        case removed = "Removed"
        case failed = "Failed"
        case tested = "Tested"
    }

    init(
        id: UUID = UUID(),
        profileName: String,
        servers: [String],
        timestamp: Date = .now,
        action: LogAction,
        latencyMs: Double? = nil
    ) {
        self.id = id
        self.profileName = profileName
        self.servers = servers
        self.timestamp = timestamp
        self.action = action
        self.latencyMs = latencyMs
    }
}

struct SpeedTestResult: Identifiable, Codable, Equatable {
    let id: UUID
    let profileName: String
    let server: String
    let latencyMs: Double
    let timestamp: Date

    init(
        id: UUID = UUID(),
        profileName: String,
        server: String,
        latencyMs: Double,
        timestamp: Date = .now
    ) {
        self.id = id
        self.profileName = profileName
        self.server = server
        self.latencyMs = latencyMs
        self.timestamp = timestamp
    }
}

enum DNSValidation {
    static func isValidIPv4(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part), (0...255).contains(num) else { return false }
            return true
        }
    }

    static func isValidIPv6(_ string: String) -> Bool {
        var sin6 = sockaddr_in6()
        return string.withCString { cstring in
            inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1
        }
    }

    static func isValidDNSServer(_ string: String) -> Bool {
        isValidIPv4(string) || isValidIPv6(string)
    }

    static func isValidDoHURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "https" && url.host != nil
    }

    static func isValidDoTHostname(_ string: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}
