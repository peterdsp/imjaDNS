import Foundation

actor PersistenceManager {
    static let shared = PersistenceManager()

    /// Shared App Group so widgets and App Intent extensions read the same store.
    private static let appGroupID = "group.dev.peterdsp.imjaDNS"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let customProfiles = "customProfiles"
        static let favoriteIDs = "favoriteProfileIDs"
        static let connectionLog = "connectionLog"
        static let activeProfileID = "activeProfileID"
        static let lastAppliedProfileID = "lastAppliedProfileID"
        static let lastUsedDNS = "lastUsedDNS"
        static let autoApplyDNS = "autoApplyDNS"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasShownDNSAlert = "hasShownDNSAlert"
        static let selectedCategory = "selectedCategory"
        static let speedTestResults = "speedTestResults"
        static let automationRules = "automationRules"
        static let didMigrateToAppGroup = "didMigrateToAppGroup"

        static let migratable = [
            customProfiles, favoriteIDs, connectionLog, activeProfileID,
            lastAppliedProfileID, lastUsedDNS, autoApplyDNS, hasCompletedOnboarding,
            hasShownDNSAlert, selectedCategory, speedTestResults, automationRules
        ]
    }

    private init() {
        if let group = UserDefaults(suiteName: Self.appGroupID) {
            defaults = group
            Self.migrateToAppGroupIfNeeded(into: group)
        } else {
            defaults = .standard
        }
    }

    /// One-time copy of existing keys from the standard suite into the App Group,
    /// so users updating from a pre-App-Group build keep their data. Idempotent:
    /// only copies keys the group doesn't already have, then sets a done flag.
    private static func migrateToAppGroupIfNeeded(into group: UserDefaults) {
        guard !group.bool(forKey: Keys.didMigrateToAppGroup) else { return }
        let standard = UserDefaults.standard
        for key in Keys.migratable where group.object(forKey: key) == nil {
            if let value = standard.object(forKey: key) {
                group.set(value, forKey: key)
            }
        }
        group.set(true, forKey: Keys.didMigrateToAppGroup)
    }

    // MARK: - Custom Profiles

    func saveCustomProfiles(_ profiles: [DNSProfile]) {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults.set(data, forKey: Keys.customProfiles)
    }

    func loadCustomProfiles() -> [DNSProfile] {
        guard let data = defaults.data(forKey: Keys.customProfiles),
              let profiles = try? decoder.decode([DNSProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    // MARK: - Favorites

    func saveFavoriteIDs(_ ids: Set<UUID>) {
        guard let data = try? encoder.encode(Array(ids)) else { return }
        defaults.set(data, forKey: Keys.favoriteIDs)
    }

    func loadFavoriteIDs() -> Set<UUID> {
        guard let data = defaults.data(forKey: Keys.favoriteIDs),
              let ids = try? decoder.decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    // MARK: - Connection Log

    func saveConnectionLog(_ entries: [ConnectionLogEntry]) {
        let trimmed = Array(entries.suffix(200))
        guard let data = try? encoder.encode(trimmed) else { return }
        defaults.set(data, forKey: Keys.connectionLog)
    }

    func loadConnectionLog() -> [ConnectionLogEntry] {
        guard let data = defaults.data(forKey: Keys.connectionLog),
              let entries = try? decoder.decode([ConnectionLogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Speed Test Results

    func saveSpeedTestResults(_ results: [SpeedTestResult]) {
        let trimmed = Array(results.suffix(100))
        guard let data = try? encoder.encode(trimmed) else { return }
        defaults.set(data, forKey: Keys.speedTestResults)
    }

    func loadSpeedTestResults() -> [SpeedTestResult] {
        guard let data = defaults.data(forKey: Keys.speedTestResults),
              let results = try? decoder.decode([SpeedTestResult].self, from: data) else {
            return []
        }
        return results
    }

    // MARK: - Active Profile

    func saveActiveProfileID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: Keys.activeProfileID)
        } else {
            defaults.removeObject(forKey: Keys.activeProfileID)
        }
    }

    func loadActiveProfileID() -> UUID? {
        guard let string = defaults.string(forKey: Keys.activeProfileID) else { return nil }
        return UUID(uuidString: string)
    }

    /// The last profile that was actually applied. Unlike `activeProfileID`, this
    /// is NOT cleared when custom DNS is disabled, so a Control Center / widget
    /// toggle can restore the profile the user last used.
    func saveLastAppliedProfileID(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.lastAppliedProfileID)
    }

    func loadLastAppliedProfileID() -> UUID? {
        guard let string = defaults.string(forKey: Keys.lastAppliedProfileID) else { return nil }
        return UUID(uuidString: string)
    }

    // MARK: - Automation Rules

    func saveAutomationRules(_ rules: [AutomationRule]) {
        guard let data = try? encoder.encode(rules) else { return }
        defaults.set(data, forKey: Keys.automationRules)
    }

    func loadAutomationRules() -> [AutomationRule] {
        guard let data = defaults.data(forKey: Keys.automationRules),
              let rules = try? decoder.decode([AutomationRule].self, from: data) else {
            return []
        }
        return rules
    }

    // MARK: - Settings

    var lastUsedDNS: String? {
        get { defaults.string(forKey: Keys.lastUsedDNS) }
        set { defaults.set(newValue, forKey: Keys.lastUsedDNS) }
    }

    var autoApplyDNS: Bool {
        get { defaults.bool(forKey: Keys.autoApplyDNS) }
        set { defaults.set(newValue, forKey: Keys.autoApplyDNS) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    var hasShownDNSAlert: Bool {
        get { defaults.bool(forKey: Keys.hasShownDNSAlert) }
        set { defaults.set(newValue, forKey: Keys.hasShownDNSAlert) }
    }

    func setAutoApplyDNS(_ value: Bool) {
        defaults.set(value, forKey: Keys.autoApplyDNS)
    }

    func markDNSAlertShown() {
        defaults.set(true, forKey: Keys.hasShownDNSAlert)
    }
}
