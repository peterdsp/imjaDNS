import Foundation
import Combine

/// Evaluates automation rules against the current context and applies the
/// matching profile — reacting to network changes (debounced) and a periodic
/// tick for time-based schedules.
///
/// Scope note: iOS does not grant apps free rein to change DNS in the
/// background, so evaluation runs while the app is active/foregrounded and on
/// next launch. Background schedule application would need a registered
/// BGAppRefreshTask (Info.plist "Background Modes" + BGTaskScheduler) — staged
/// as a future enhancement.
@MainActor
final class AutomationEngine {
    static let shared = AutomationEngine()
    private init() {}

    private var cancellables = Set<AnyCancellable>()
    private var scheduleTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    /// The target we last applied, to avoid redundantly re-applying.
    private var lastAppliedTarget: UUID??

    /// Begins observing network changes and time-of-day for schedule rules.
    func start() {
        NetworkMonitor.shared.$connectionType
            .removeDuplicates()
            .sink { [weak self] _ in self?.evaluateDebounced() }
            .store(in: &cancellables)

        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.evaluate() }
        }

        Task { await evaluate() }
    }

    /// Coalesces bursty network flaps into a single evaluation after a settle.
    func evaluateDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.evaluate()
        }
    }

    func evaluate() async {
        let rules = await PersistenceManager.shared.loadAutomationRules()
        guard rules.contains(where: \.isEnabled) else { return }

        let context = await currentContext()
        guard let rule = AutomationMatcher.firstMatch(rules: rules, context: context) else { return }
        await applyTarget(rule.profileID)
    }

    private func currentContext() async -> AutomationMatcher.Context {
        let type = NetworkMonitor.shared.connectionType
        let ssid = type == .wifi ? await WiFiSSIDProvider.currentSSID() : nil
        return AutomationMatcher.Context.now(connectionType: type, ssid: ssid, date: Date())
    }

    private func applyTarget(_ profileID: UUID?) async {
        // Skip if we already applied this exact target and it's still active.
        let activeID = await PersistenceManager.shared.loadActiveProfileID()
        if lastAppliedTarget == .some(profileID) && activeID == profileID { return }

        do {
            if let profileID {
                guard let profile = await ProfileProvider.profile(for: profileID) else { return }
                try await DNSApplyService.apply(profile)
            } else {
                try await DNSApplyService.disable()
            }
            lastAppliedTarget = .some(profileID)
        } catch {
            // Leave lastAppliedTarget unchanged so a later tick retries.
        }
    }
}
