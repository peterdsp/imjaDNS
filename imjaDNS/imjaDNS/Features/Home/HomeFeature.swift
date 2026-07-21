import ComposableArchitecture
import Foundation
import UIKit
import WidgetKit

@Reducer
struct HomeFeature {
    private enum CancelID { case statusWatch }

    @ObservableState
    struct State: Equatable {
        var currentDNS: String = "Loading..."
        var dnsStatus: DNSStatus = .off
        /// The servers are actually resolving traffic.
        var isCustomDNSActive: Bool { dnsStatus == .active }
        /// A profile exists on the device, whether or not it is switched on.
        var hasProfileInstalled: Bool { dnsStatus != .off }
        var networkType: String = "Checking..."
        var networkIcon: String = "wifi"
        var activeProfileName: String? = nil
        var showFirstTimeAlert: Bool = false
        var isApplying: Bool = false
        var errorMessage: String? = nil
        var latencyMs: Double? = nil
        var isTestingLatency: Bool = false

        // Dashboard cards
        var lastSpeedResult: InternetSpeedResult? = nil
        var recentActivity: [ConnectionLogEntry] = []
    }

    enum Action: Equatable {
        case onAppear
        case refreshDNSStatus
        case dnsStatusLoaded(String, DNSStatus)
        case dashboardLoaded(InternetSpeedResult?, [ConnectionLogEntry])
        case networkUpdated(String, String)
        case disconnectDNS
        case dnsDisconnected
        case showError(String)
        case dismissError
        case toggleFirstTimeAlert(Bool)
        case latencyResult(Double?)
        case testLatency
        case setApplying(Bool)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .run { send in
                        let display = await DNSManager.shared.currentServersDisplay()
                        let status = await DNSManager.shared.status()
                        await send(.dnsStatusLoaded(display, status))
                        await send(.dashboardLoaded(
                            await PersistenceManager.shared.loadInternetSpeedResult(),
                            await Self.recentActivity()
                        ))

                        let hasShown = await PersistenceManager.shared.hasShownDNSAlert
                        if !hasShown {
                            await send(.toggleFirstTimeAlert(true))
                            await PersistenceManager.shared.markDNSAlertShown()
                        }
                    },
                    .run { send in
                        // The profile is switched on and off in Settings, out of
                        // our reach, so a single read on appear goes stale the
                        // moment the user leaves. Re-read whenever the system
                        // reports a change and whenever we come back forward.
                        await withTaskGroup(of: Void.self) { group in
                            group.addTask {
                                for await _ in NotificationCenter.default.notifications(named: .dnsConfigurationDidChange) {
                                    await send(.refreshDNSStatus)
                                }
                            }
                            group.addTask {
                                for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                                    await send(.refreshDNSStatus)
                                }
                            }
                        }
                    }
                    .cancellable(id: CancelID.statusWatch, cancelInFlight: true)
                )

            case .refreshDNSStatus:
                return .run { send in
                    let display = await DNSManager.shared.currentServersDisplay()
                    let status = await DNSManager.shared.status()
                    await send(.dnsStatusLoaded(display, status))
                    await send(.dashboardLoaded(
                        await PersistenceManager.shared.loadInternetSpeedResult(),
                        await Self.recentActivity()
                    ))
                }

            case let .dashboardLoaded(speed, activity):
                state.lastSpeedResult = speed
                state.recentActivity = activity
                return .none

            case let .dnsStatusLoaded(dns, status):
                let wasActive = state.dnsStatus == .active
                state.currentDNS = dns
                state.dnsStatus = status

                guard status == .active else {
                    // A reading from a resolver we are no longer using would be
                    // a stale claim, so drop it.
                    state.latencyMs = nil
                    return .none
                }
                // Newly active — usually because the user just enabled us in
                // Settings — so the badge has nothing to show until we measure.
                guard !wasActive, !state.isTestingLatency else { return .none }
                return .send(.testLatency)

            case let .networkUpdated(type, icon):
                state.networkType = type
                state.networkIcon = icon
                return .none

            case .disconnectDNS:
                state.isApplying = true
                return .run { send in
                    do {
                        try await DNSManager.shared.disableCustomDNS()
                        await send(.dnsDisconnected)
                    } catch {
                        await send(.showError(error.localizedDescription))
                    }
                    await send(.setApplying(false))
                }

            case .dnsDisconnected:
                state.currentDNS = "System Default"
                state.dnsStatus = .off
                state.activeProfileName = nil
                state.latencyMs = nil
                return .none

            case let .showError(message):
                state.errorMessage = message
                state.isApplying = false
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case let .toggleFirstTimeAlert(show):
                state.showFirstTimeAlert = show
                return .none

            case .testLatency:
                state.isTestingLatency = true
                return .run { [dns = state.currentDNS] send in
                    let servers = dns.components(separatedBy: ", ")
                    if let server = servers.first {
                        let timeout = await SpeedProbe.adaptiveTimeout()
                        let latency = await DNSManager.shared.testLatency(server: server, timeout: timeout)
                        await send(.latencyResult(latency))
                    } else {
                        await send(.latencyResult(nil))
                    }
                }

            case let .latencyResult(ms):
                state.latencyMs = ms
                state.isTestingLatency = false
                return .run { _ in
                    WidgetStateStore.updateLatency(ms)
                    WidgetCenter.shared.reloadAllTimelines()
                }

            case let .setApplying(value):
                state.isApplying = value
                return .none
            }
        }
    }

    /// The three most recent connection-log entries, newest first, for the
    /// dashboard's activity card.
    private static func recentActivity() async -> [ConnectionLogEntry] {
        let log = await PersistenceManager.shared.loadConnectionLog()
        return Array(log.suffix(3).reversed())
    }
}