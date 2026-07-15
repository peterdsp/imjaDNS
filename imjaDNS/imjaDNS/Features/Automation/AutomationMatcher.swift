import Foundation

/// Pure rule-matching logic — no I/O, fully unit-testable. Priority is list
/// order: the first enabled rule that matches wins.
enum AutomationMatcher {
    struct Context: Equatable {
        let connectionType: NetworkMonitor.ConnectionType
        let ssid: String?
        let minuteOfDay: Int   // 0...1439

        static func now(connectionType: NetworkMonitor.ConnectionType, ssid: String?, date: Date, calendar: Calendar = .current) -> Context {
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            return Context(connectionType: connectionType, ssid: ssid, minuteOfDay: minute)
        }
    }

    static func firstMatch(rules: [AutomationRule], context: Context) -> AutomationRule? {
        rules.first { $0.isEnabled && matches($0.trigger, context) }
    }

    static func matches(_ trigger: AutomationRule.Trigger, _ ctx: Context) -> Bool {
        switch trigger {
        case .anyWifi:
            return ctx.connectionType == .wifi
        case .cellular:
            return ctx.connectionType == .cellular
        case .ssid(let name):
            return ctx.connectionType == .wifi && ctx.ssid == name
        case let .schedule(start, end):
            if start == end { return false }
            if start < end {
                return ctx.minuteOfDay >= start && ctx.minuteOfDay < end
            } else {
                // Window wraps past midnight, e.g. 22:00–06:00.
                return ctx.minuteOfDay >= start || ctx.minuteOfDay < end
            }
        }
    }
}
