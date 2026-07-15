import Foundation

/// Snapshot of what the Home/Lock Screen widget and Control Center show. Written
/// by the app into the App Group whenever DNS or latency changes; read by the
/// widget extension. Kept small and Codable so both processes share it cheaply.
struct WidgetState: Codable, Equatable {
    var isActive: Bool
    var profileName: String
    var categoryIcon: String   // SF Symbol name
    var gradient: [String]     // hex colors, e.g. ["#6C63FF", "#3F37C9"]
    var latencyMs: Double?
    var updatedAt: Date

    static let systemDefault = WidgetState(
        isActive: false,
        profileName: "System Default",
        categoryIcon: "shield.slash",
        gradient: ["#64708F", "#9AA6C4"],
        latencyMs: nil,
        updatedAt: .distantPast
    )

    /// True when the latency reading is fresh enough to display (< 24h old).
    var hasFreshLatency: Bool {
        guard latencyMs != nil else { return false }
        return Date().timeIntervalSince(updatedAt) < 24 * 60 * 60
    }
}

/// Synchronous App Group accessor usable from both the app and the widget
/// extension (no actor hop — WidgetKit timeline providers need a fast read).
enum WidgetStateStore {
    private static let appGroupID = "group.dev.peterdsp.imjaDNS"
    private static let key = "widgetState"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ state: WidgetState) {
        guard let defaults, let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetState {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(WidgetState.self, from: data) else {
            return .systemDefault
        }
        return state
    }

    /// Updates only the latency of the stored state, preserving the rest.
    static func updateLatency(_ ms: Double?) {
        var state = load()
        state.latencyMs = ms
        state.updatedAt = Date()
        save(state)
    }
}
