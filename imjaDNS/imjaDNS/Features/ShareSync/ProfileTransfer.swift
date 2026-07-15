import Foundation

/// Encodes/decodes profiles for `.json` export files and QR codes, and
/// sanitizes imported profiles before they touch storage.
enum ProfileTransfer {
    static func encode(_ profiles: [DNSProfile]) throws -> Data {
        try JSONEncoder().encode(profiles)
    }

    static func decode(_ data: Data) throws -> [DNSProfile] {
        try JSONDecoder().decode([DNSProfile].self, from: data)
    }

    /// Validates and normalizes imported profiles: drops anything without a
    /// usable resolver, reassigns fresh ids to avoid collisions, and forces
    /// them to be non-builtin, non-favorite custom profiles.
    static func sanitize(_ profiles: [DNSProfile]) -> [DNSProfile] {
        profiles.compactMap { profile in
            let serversOK = !profile.servers.isEmpty
                && profile.servers.allSatisfy(DNSValidation.isValidDNSServer)
            let dohOK = profile.protocolType == .doh
                && (profile.dohURL.map(DNSValidation.isValidDoHURL) ?? false)
            guard serversOK || dohOK else { return nil }

            return DNSProfile(
                id: UUID(),
                name: profile.name.isEmpty ? "Imported profile" : profile.name,
                servers: profile.servers,
                category: profile.category,
                protocolType: profile.protocolType,
                description: profile.description,
                website: profile.website,
                isFavorite: false,
                isBuiltIn: false,
                dohURL: profile.dohURL,
                dotHostname: profile.dotHostname
            )
        }
    }
}
