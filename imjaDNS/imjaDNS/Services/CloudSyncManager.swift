import Foundation

/// Optional iCloud sync of user data — custom profiles, favorites, and
/// automation rules — via `NSUbiquitousKeyValueStore`. These are small Codable
/// blobs, well under the 1 MB KVS limit, so KVS beats a full CloudKit setup.
///
/// Opt-in and privacy-preserving: only user-created configuration syncs; no
/// browsing data, no DNS queries, nothing about what you resolve. Without the
/// iCloud Key-Value Storage capability the store is a harmless no-op.
@MainActor
final class CloudSyncManager {
    static let shared = CloudSyncManager()
    private init() {}

    private let kvs = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    private enum Keys {
        static let customProfiles = "customProfiles"
        static let favoriteIDs = "favoriteProfileIDs"
        static let automationRules = "automationRules"
    }

    private static let appGroupID = "group.dev.peterdsp.imjaDNS"
    private static let enabledKey = "iCloudSyncEnabled"

    var isEnabled: Bool {
        get { UserDefaults(suiteName: Self.appGroupID)?.bool(forKey: Self.enabledKey) ?? false }
        set {
            UserDefaults(suiteName: Self.appGroupID)?.set(newValue, forKey: Self.enabledKey)
            if newValue {
                start()
                Task { await pushLocalToCloud() }
            } else {
                stop()
            }
        }
    }

    /// Begins observing external (other-device) changes. Safe to call on launch.
    func start() {
        guard isEnabled, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { _ in
            Task { @MainActor in await CloudSyncManager.shared.pullCloudToLocal() }
        }
        kvs.synchronize()
        Task { await pullCloudToLocal() }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// Uploads current local data to iCloud.
    func pushLocalToCloud() async {
        let profiles = await PersistenceManager.shared.loadCustomProfiles()
        let favorites = await PersistenceManager.shared.loadFavoriteIDs()
        let rules = await PersistenceManager.shared.loadAutomationRules()

        if let data = try? JSONEncoder().encode(profiles) { kvs.set(data, forKey: Keys.customProfiles) }
        if let data = try? JSONEncoder().encode(Array(favorites)) { kvs.set(data, forKey: Keys.favoriteIDs) }
        if let data = try? JSONEncoder().encode(rules) { kvs.set(data, forKey: Keys.automationRules) }
        kvs.synchronize()
    }

    /// Merges iCloud data into local storage (union by id — additive, so a
    /// delete on one device doesn't wipe another's data unexpectedly).
    func pullCloudToLocal() async {
        if let data = kvs.data(forKey: Keys.customProfiles),
           let cloud = try? JSONDecoder().decode([DNSProfile].self, from: data) {
            var local = await PersistenceManager.shared.loadCustomProfiles()
            let known = Set(local.map(\.id))
            local.append(contentsOf: cloud.filter { !known.contains($0.id) })
            await PersistenceManager.shared.saveCustomProfiles(local)
        }
        if let data = kvs.data(forKey: Keys.favoriteIDs),
           let cloud = try? JSONDecoder().decode([UUID].self, from: data) {
            var favorites = await PersistenceManager.shared.loadFavoriteIDs()
            favorites.formUnion(cloud)
            await PersistenceManager.shared.saveFavoriteIDs(favorites)
        }
        if let data = kvs.data(forKey: Keys.automationRules),
           let cloud = try? JSONDecoder().decode([AutomationRule].self, from: data) {
            var rules = await PersistenceManager.shared.loadAutomationRules()
            let known = Set(rules.map(\.id))
            rules.append(contentsOf: cloud.filter { !known.contains($0.id) })
            await PersistenceManager.shared.saveAutomationRules(rules)
        }
    }
}
