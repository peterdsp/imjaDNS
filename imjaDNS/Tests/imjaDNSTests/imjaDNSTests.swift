import Testing
import Foundation
@testable import imjaDNS

// MARK: - DNS Validation Tests

struct DNSValidationTests {
    @Test func validIPv4Addresses() {
        #expect(DNSValidation.isValidIPv4("1.1.1.1"))
        #expect(DNSValidation.isValidIPv4("8.8.8.8"))
        #expect(DNSValidation.isValidIPv4("192.168.0.1"))
        #expect(DNSValidation.isValidIPv4("0.0.0.0"))
        #expect(DNSValidation.isValidIPv4("255.255.255.255"))
    }

    @Test func invalidIPv4Addresses() {
        #expect(!DNSValidation.isValidIPv4(""))
        #expect(!DNSValidation.isValidIPv4("1.1.1"))
        #expect(!DNSValidation.isValidIPv4("256.1.1.1"))
        #expect(!DNSValidation.isValidIPv4("abc.def.ghi.jkl"))
        #expect(!DNSValidation.isValidIPv4("1.1.1.1.1"))
        #expect(!DNSValidation.isValidIPv4("hello"))
        #expect(!DNSValidation.isValidIPv4("-1.0.0.0"))
    }

    @Test func validIPv6Addresses() {
        #expect(DNSValidation.isValidIPv6("::1"))
        #expect(DNSValidation.isValidIPv6("2001:4860:4860::8888"))
        #expect(DNSValidation.isValidIPv6("fe80::1"))
    }

    @Test func invalidIPv6Addresses() {
        #expect(!DNSValidation.isValidIPv6(""))
        #expect(!DNSValidation.isValidIPv6("1.1.1.1"))
        #expect(!DNSValidation.isValidIPv6("not-an-ipv6"))
    }

    @Test func validDNSServer() {
        #expect(DNSValidation.isValidDNSServer("1.1.1.1"))
        #expect(DNSValidation.isValidDNSServer("8.8.8.8"))
        #expect(DNSValidation.isValidDNSServer("::1"))
        #expect(DNSValidation.isValidDNSServer("2001:4860:4860::8888"))
    }

    @Test func invalidDNSServer() {
        #expect(!DNSValidation.isValidDNSServer(""))
        #expect(!DNSValidation.isValidDNSServer("example.com"))
        #expect(!DNSValidation.isValidDNSServer("not-a-server"))
    }

    @Test func validDoHURLs() {
        #expect(DNSValidation.isValidDoHURL("https://cloudflare-dns.com/dns-query"))
        #expect(DNSValidation.isValidDoHURL("https://dns.google/dns-query"))
    }

    @Test func invalidDoHURLs() {
        #expect(!DNSValidation.isValidDoHURL(""))
        #expect(!DNSValidation.isValidDoHURL("http://insecure.com/dns"))
        #expect(!DNSValidation.isValidDoHURL("not-a-url"))
    }

    @Test func validDoTHostnames() {
        #expect(DNSValidation.isValidDoTHostname("one.one.one.one"))
        #expect(DNSValidation.isValidDoTHostname("dns.google"))
        #expect(DNSValidation.isValidDoTHostname("dns.quad9.net"))
    }

    @Test func invalidDoTHostnames() {
        #expect(!DNSValidation.isValidDoTHostname(""))
        #expect(!DNSValidation.isValidDoTHostname("-invalid.com"))
        #expect(!DNSValidation.isValidDoTHostname("has spaces.com"))
    }
}

// MARK: - DNSProfile Model Tests

struct DNSProfileModelTests {
    @Test func profileCreation() {
        let profile = DNSProfile(
            name: "Test DNS",
            servers: ["1.1.1.1", "1.0.0.1"],
            category: .privacy,
            protocolType: .doh,
            description: "Test profile"
        )

        #expect(profile.name == "Test DNS")
        #expect(profile.servers == ["1.1.1.1", "1.0.0.1"])
        #expect(profile.category == .privacy)
        #expect(profile.protocolType == .doh)
        #expect(profile.primaryServer == "1.1.1.1")
        #expect(profile.serversDisplay == "1.1.1.1, 1.0.0.1")
        #expect(profile.isBuiltIn == false)
        #expect(profile.isFavorite == false)
    }

    @Test func profileCodable() throws {
        let original = DNSProfile(
            name: "Cloudflare",
            servers: ["1.1.1.1"],
            category: .privacy,
            protocolType: .doh,
            description: "Test",
            dohURL: "https://cloudflare-dns.com/dns-query"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DNSProfile.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.servers == original.servers)
        #expect(decoded.category == original.category)
        #expect(decoded.protocolType == original.protocolType)
        #expect(decoded.dohURL == original.dohURL)
    }

    @Test func profileDecodingWithStringServers() throws {
        let json = """
        {"name":"Test","servers":"1.1.1.1, 8.8.8.8"}
        """
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(DNSProfile.self, from: data)

        #expect(profile.name == "Test")
        #expect(profile.servers == ["1.1.1.1", "8.8.8.8"])
    }

    @Test func profileDecodingWithArrayServers() throws {
        let json = """
        {"name":"Test","servers":["1.1.1.1","8.8.8.8"]}
        """
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(DNSProfile.self, from: data)

        #expect(profile.servers == ["1.1.1.1", "8.8.8.8"])
    }

    @Test func profileDecodingGeneratesUUID() throws {
        let json = """
        {"name":"Test","servers":["1.1.1.1"]}
        """
        let data = json.data(using: .utf8)!
        let profile1 = try JSONDecoder().decode(DNSProfile.self, from: data)
        let profile2 = try JSONDecoder().decode(DNSProfile.self, from: data)

        #expect(profile1.id != profile2.id)
    }

    @Test func primaryServerReturnsFirst() {
        let profile = DNSProfile(name: "Test", servers: ["8.8.8.8", "8.8.4.4"])
        #expect(profile.primaryServer == "8.8.8.8")
    }

    @Test func primaryServerEmptyOnNoServers() {
        let profile = DNSProfile(name: "Test", servers: [])
        #expect(profile.primaryServer == "")
    }
}

// MARK: - DNSCategory Tests

struct DNSCategoryTests {
    @Test func allCategoriesHaveIcons() {
        for category in DNSCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    @Test func allCategoriesHaveGradients() {
        for category in DNSCategory.allCases {
            #expect(category.gradient.count == 2)
        }
    }

    @Test func categoryRawValues() {
        #expect(DNSCategory.privacy.rawValue == "Privacy")
        #expect(DNSCategory.speed.rawValue == "Speed")
        #expect(DNSCategory.familySafe.rawValue == "Family Safe")
        #expect(DNSCategory.security.rawValue == "Security")
        #expect(DNSCategory.gaming.rawValue == "Gaming")
        #expect(DNSCategory.custom.rawValue == "Custom")
    }
}

// MARK: - DNSProtocolType Tests

struct DNSProtocolTypeTests {
    @Test func displayNames() {
        #expect(DNSProtocolType.plain.displayName == "Standard DNS")
        #expect(DNSProtocolType.doh.displayName == "DNS over HTTPS")
        #expect(DNSProtocolType.dot.displayName == "DNS over TLS")
    }
}

// MARK: - ConnectionLogEntry Tests

struct ConnectionLogEntryTests {
    @Test func entryCreation() {
        let entry = ConnectionLogEntry(
            profileName: "Cloudflare",
            servers: ["1.1.1.1"],
            action: .applied,
            latencyMs: 12.5
        )

        #expect(entry.profileName == "Cloudflare")
        #expect(entry.servers == ["1.1.1.1"])
        #expect(entry.action == .applied)
        #expect(entry.latencyMs == 12.5)
    }

    @Test func entryActionValues() {
        #expect(ConnectionLogEntry.LogAction.applied.rawValue == "Applied")
        #expect(ConnectionLogEntry.LogAction.removed.rawValue == "Removed")
        #expect(ConnectionLogEntry.LogAction.failed.rawValue == "Failed")
        #expect(ConnectionLogEntry.LogAction.tested.rawValue == "Tested")
    }

    @Test func entryCodable() throws {
        let entry = ConnectionLogEntry(
            profileName: "Test",
            servers: ["8.8.8.8"],
            action: .applied,
            latencyMs: 15.0
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ConnectionLogEntry.self, from: data)

        #expect(decoded.profileName == entry.profileName)
        #expect(decoded.action == entry.action)
        #expect(decoded.latencyMs == entry.latencyMs)
    }
}

// MARK: - SpeedTestResult Tests

struct SpeedTestResultTests {
    @Test func resultCreation() {
        let result = SpeedTestResult(
            profileName: "Google DNS",
            server: "8.8.8.8",
            latencyMs: 25.3
        )

        #expect(result.profileName == "Google DNS")
        #expect(result.server == "8.8.8.8")
        #expect(result.latencyMs == 25.3)
    }

    @Test func resultCodable() throws {
        let result = SpeedTestResult(
            profileName: "Test",
            server: "1.1.1.1",
            latencyMs: 10.0
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SpeedTestResult.self, from: data)

        #expect(decoded.profileName == result.profileName)
        #expect(decoded.server == result.server)
        #expect(decoded.latencyMs == result.latencyMs)
    }
}

// MARK: - DNSProfileCatalog Tests

struct DNSProfileCatalogTests {
    @Test func catalogHasProfiles() {
        #expect(!DNSProfileCatalog.builtIn.isEmpty)
    }

    @Test func catalogHasAllCategories() {
        let categories = Set(DNSProfileCatalog.builtIn.map(\.category))
        #expect(categories.contains(.privacy))
        #expect(categories.contains(.speed))
        #expect(categories.contains(.familySafe))
        #expect(categories.contains(.security))
        #expect(categories.contains(.gaming))
    }

    @Test func allBuiltInProfilesHaveValidServers() {
        for profile in DNSProfileCatalog.builtIn {
            #expect(!profile.servers.isEmpty, "Profile \(profile.name) has no servers")
            for server in profile.servers {
                #expect(DNSValidation.isValidDNSServer(server),
                       "Profile \(profile.name) has invalid server: \(server)")
            }
        }
    }

    @Test func allBuiltInProfilesAreMarkedBuiltIn() {
        for profile in DNSProfileCatalog.builtIn {
            #expect(profile.isBuiltIn, "Profile \(profile.name) should be marked as built-in")
        }
    }

    @Test func allBuiltInProfilesHaveDescriptions() {
        for profile in DNSProfileCatalog.builtIn {
            #expect(!profile.description.isEmpty, "Profile \(profile.name) has no description")
        }
    }

    @Test func allBuiltInProfilesHaveNames() {
        for profile in DNSProfileCatalog.builtIn {
            #expect(!profile.name.isEmpty)
        }
    }

    @Test func dohProfilesHaveURLs() {
        for profile in DNSProfileCatalog.builtIn where profile.protocolType == .doh {
            #expect(profile.dohURL != nil, "DoH profile \(profile.name) missing DoH URL")
            if let url = profile.dohURL {
                #expect(DNSValidation.isValidDoHURL(url),
                       "Profile \(profile.name) has invalid DoH URL: \(url)")
            }
        }
    }

    @Test func filterByCategory() {
        let privacyProfiles = DNSProfileCatalog.profiles(for: .privacy)
        #expect(!privacyProfiles.isEmpty)
        #expect(privacyProfiles.allSatisfy { $0.category == .privacy })
    }

    @Test func profileNamesAreUnique() {
        let names = DNSProfileCatalog.builtIn.map(\.name)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count, "Duplicate profile names found")
    }
}

// MARK: - DNSError Tests

struct DNSErrorTests {
    @Test func errorDescriptions() {
        let errors: [DNSError] = [
            .noServersProvided,
            .invalidServer("bad"),
            .configurationNotFound,
            .loadFailed(NSError(domain: "test", code: 1)),
            .saveFailed(NSError(domain: "test", code: 2)),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}
