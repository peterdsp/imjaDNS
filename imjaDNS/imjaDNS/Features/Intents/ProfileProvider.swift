import Foundation

/// Read-only access to the full profile set (built-in + user custom) and the
/// active/last-applied profile, shared by App Intents, the entity query, and
/// the Control Center toggle. All lookups go through `PersistenceManager`, so
/// they read the App Group store and work out-of-process.
enum ProfileProvider {
    static var builtIn: [DNSProfile] { DNSProfileCatalog.builtIn }

    static func allProfiles() async -> [DNSProfile] {
        let custom = await PersistenceManager.shared.loadCustomProfiles()
        return DNSProfileCatalog.builtIn + custom
    }

    static func profile(for id: UUID) async -> DNSProfile? {
        await allProfiles().first { $0.id == id }
    }

    /// The profile currently applied, or nil when using system default.
    static func activeProfile() async -> DNSProfile? {
        guard let id = await PersistenceManager.shared.loadActiveProfileID() else { return nil }
        return await profile(for: id)
    }

    /// Favorited profiles, falling back to the first few built-ins so the
    /// widget's quick-switch always has something to show.
    static func favorites(limit: Int = 3) async -> [DNSProfile] {
        let ids = await PersistenceManager.shared.loadFavoriteIDs()
        let all = await allProfiles()
        let favorites = all.filter { ids.contains($0.id) }
        let chosen = favorites.isEmpty ? all : favorites
        return Array(chosen.prefix(limit))
    }

    /// Best guess of what to re-enable from a toggle: the last applied profile,
    /// then the active one, then the first available profile.
    static func profileToEnable() async -> DNSProfile? {
        if let id = await PersistenceManager.shared.loadLastAppliedProfileID(),
           let profile = await profile(for: id) {
            return profile
        }
        if let active = await activeProfile() { return active }
        return await allProfiles().first
    }
}
