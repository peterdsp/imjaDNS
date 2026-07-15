import AppIntents

/// Registers Siri phrases and the Shortcuts app tiles. Phrases must contain
/// `\(.applicationName)`; the switch phrases also bind the profile parameter so
/// users can say the provider by name.
struct imjaDNSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SwitchDNSProfileIntent(),
            phrases: [
                "Switch \(.applicationName) to \(\.$profile)",
                "Set \(.applicationName) profile to \(\.$profile)"
            ],
            shortTitle: "Switch Profile",
            systemImageName: "shield.lefthalf.filled"
        )
        AppShortcut(
            intent: DisableCustomDNSIntent(),
            phrases: [
                "Turn off \(.applicationName)",
                "Disable \(.applicationName) DNS"
            ],
            shortTitle: "Turn Off DNS",
            systemImageName: "xmark.shield"
        )
        AppShortcut(
            intent: RunSpeedTestIntent(),
            phrases: [
                "Run a \(.applicationName) speed test",
                "Test my DNS with \(.applicationName)"
            ],
            shortTitle: "Speed Test",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: CurrentDNSIntent(),
            phrases: [
                "Check my \(.applicationName) status",
                "What DNS is \(.applicationName) using"
            ],
            shortTitle: "Current DNS",
            systemImageName: "shield"
        )
    }
}
