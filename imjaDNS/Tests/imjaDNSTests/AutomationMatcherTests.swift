import Testing
import Foundation
@testable import imjaDNS

struct AutomationMatcherTests {
    private func ctx(_ type: NetworkMonitor.ConnectionType, ssid: String? = nil, minute: Int = 0) -> AutomationMatcher.Context {
        AutomationMatcher.Context(connectionType: type, ssid: ssid, minuteOfDay: minute)
    }

    @Test func anyWifiMatchesOnlyWifi() {
        #expect(AutomationMatcher.matches(.anyWifi, ctx(.wifi)))
        #expect(!AutomationMatcher.matches(.anyWifi, ctx(.cellular)))
    }

    @Test func ssidRequiresWifiAndName() {
        #expect(AutomationMatcher.matches(.ssid("Home"), ctx(.wifi, ssid: "Home")))
        #expect(!AutomationMatcher.matches(.ssid("Home"), ctx(.wifi, ssid: "Cafe")))
        #expect(!AutomationMatcher.matches(.ssid("Home"), ctx(.cellular, ssid: "Home")))
        #expect(!AutomationMatcher.matches(.ssid("Home"), ctx(.wifi, ssid: nil)))
    }

    @Test func scheduleWithinDay() {
        let trigger = AutomationRule.Trigger.schedule(startMinute: 8 * 60, endMinute: 20 * 60)
        #expect(AutomationMatcher.matches(trigger, ctx(.wifi, minute: 12 * 60)))
        #expect(!AutomationMatcher.matches(trigger, ctx(.wifi, minute: 7 * 60)))
        #expect(!AutomationMatcher.matches(trigger, ctx(.wifi, minute: 20 * 60)))  // end exclusive
    }

    @Test func scheduleWrappingMidnight() {
        let trigger = AutomationRule.Trigger.schedule(startMinute: 22 * 60, endMinute: 6 * 60)
        #expect(AutomationMatcher.matches(trigger, ctx(.cellular, minute: 23 * 60)))
        #expect(AutomationMatcher.matches(trigger, ctx(.cellular, minute: 2 * 60)))
        #expect(!AutomationMatcher.matches(trigger, ctx(.cellular, minute: 12 * 60)))
    }

    @Test func firstEnabledMatchWins() {
        let home = AutomationRule(trigger: .ssid("Home"), profileID: UUID())
        let anyWifi = AutomationRule(trigger: .anyWifi, profileID: UUID())
        let rules = [home, anyWifi]
        let match = AutomationMatcher.firstMatch(rules: rules, context: ctx(.wifi, ssid: "Home"))
        #expect(match?.id == home.id)
    }

    @Test func disabledRulesAreSkipped() {
        var disabled = AutomationRule(trigger: .anyWifi, profileID: UUID())
        disabled.isEnabled = false
        let match = AutomationMatcher.firstMatch(rules: [disabled], context: ctx(.wifi))
        #expect(match == nil)
    }
}
