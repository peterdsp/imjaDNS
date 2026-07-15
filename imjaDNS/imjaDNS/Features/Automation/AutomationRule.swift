import Foundation

/// A single automation rule: "when <trigger>, apply <profile> (or disable)".
struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: Trigger
    /// Target profile to apply; `nil` means revert to system default.
    var profileID: UUID?
    var isEnabled: Bool

    init(id: UUID = UUID(), trigger: Trigger, profileID: UUID?, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.profileID = profileID
        self.isEnabled = isEnabled
    }

    enum Trigger: Codable, Equatable {
        case anyWifi
        case cellular
        case ssid(String)
        /// Minutes from midnight (0...1439). May wrap past midnight (start > end).
        case schedule(startMinute: Int, endMinute: Int)

        var summary: String {
            switch self {
            case .anyWifi: return "On any Wi-Fi"
            case .cellular: return "On cellular"
            case .ssid(let name): return "On Wi-Fi \"\(name)\""
            case let .schedule(start, end):
                return "From \(Self.clock(start)) to \(Self.clock(end))"
            }
        }

        private static func clock(_ minutes: Int) -> String {
            let h = (minutes / 60) % 24
            let m = minutes % 60
            return String(format: "%02d:%02d", h, m)
        }
    }
}
