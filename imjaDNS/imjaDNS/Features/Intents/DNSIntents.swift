import AppIntents

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case profileNotFound
    case nothingToEnable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .profileNotFound: return "That DNS profile no longer exists."
        case .nothingToEnable: return "No DNS profile is available to enable."
        }
    }
}

/// "Switch to <profile>" — applies a chosen profile system-wide.
struct SwitchDNSProfileIntent: AppIntent {
    static var title: LocalizedStringResource { "Switch DNS Profile" }
    static var description: IntentDescription {
        IntentDescription("Apply a DNS profile to your device, system-wide.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Profile")
    var profile: ProfileEntity

    init() {}
    init(profile: ProfileEntity) { self.profile = profile }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let full = await ProfileProvider.profile(for: profile.id) else {
            throw IntentError.profileNotFound
        }
        try await DNSApplyService.apply(full)
        return .result(dialog: "Switched to \(profile.name).")
    }
}

/// "Turn off imjaDNS" — reverts to the system default resolver.
struct DisableCustomDNSIntent: AppIntent {
    static var title: LocalizedStringResource { "Turn Off Custom DNS" }
    static var description: IntentDescription {
        IntentDescription("Revert to your system's default DNS.")
    }
    static var openAppWhenRun: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await DNSApplyService.disable()
        return .result(dialog: "Custom DNS turned off — using system default.")
    }
}

/// "Run a speed test" — probes providers and reports the fastest.
struct RunSpeedTestIntent: AppIntent {
    static var title: LocalizedStringResource { "Run DNS Speed Test" }
    static var description: IntentDescription {
        IntentDescription("Measure latency across providers and report the fastest.")
    }
    static var openAppWhenRun: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let timeout = SpeedProbe.adaptiveTimeout()
        guard let best = await SpeedProbe.fastest(among: ProfileProvider.builtIn, timeout: timeout) else {
            return .result(value: "No response", dialog: "Couldn't reach any DNS provider.")
        }
        let rounded = Int(best.latencyMs.rounded())
        return .result(value: best.profile.name, dialog: "Fastest provider: \(best.profile.name) at \(rounded) ms.")
    }
}

/// "What's my DNS?" — reports the currently active profile.
struct CurrentDNSIntent: AppIntent {
    static var title: LocalizedStringResource { "Current DNS" }
    static var description: IntentDescription {
        IntentDescription("Report the DNS profile currently active.")
    }
    static var openAppWhenRun: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        if let active = await ProfileProvider.activeProfile() {
            return .result(value: active.name, dialog: "Your active DNS is \(active.name).")
        }
        let servers = await DNSManager.shared.currentServersDisplay()
        return .result(value: servers, dialog: "You're using \(servers).")
    }
}

/// Backing intent for the Control Center toggle (and any on/off switch): enable
/// restores the last-used profile; disable reverts to system default.
struct SetDNSEnabledIntent: SetValueIntent {
    static var title: LocalizedStringResource { "Toggle imjaDNS" }

    @Parameter(title: "Enabled")
    var value: Bool

    init() {}
    init(value: Bool) { self.value = value }

    @MainActor
    func perform() async throws -> some IntentResult {
        if value {
            guard let profile = await ProfileProvider.profileToEnable() else {
                throw IntentError.nothingToEnable
            }
            try await DNSApplyService.apply(profile)
        } else {
            try await DNSApplyService.disable()
        }
        return .result()
    }
}
