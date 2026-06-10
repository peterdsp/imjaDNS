import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var currentDNS: String = "Loading..."
        var isCustomDNSActive: Bool = false
        var networkType: String = "Checking..."
        var networkIcon: String = "wifi"
        var activeProfileName: String? = nil
        var showFirstTimeAlert: Bool = false
        var isApplying: Bool = false
        var errorMessage: String? = nil
        var latencyMs: Double? = nil
        var isTestingLatency: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case refreshDNSStatus
        case dnsStatusLoaded(String, Bool)
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
                return .run { send in
                    let display = await DNSManager.shared.currentServersDisplay()
                    let active = await DNSManager.shared.isCustomDNSActive()
                    await send(.dnsStatusLoaded(display, active))

                    let hasShown = await PersistenceManager.shared.hasShownDNSAlert
                    if !hasShown {
                        await send(.toggleFirstTimeAlert(true))
                        await PersistenceManager.shared.markDNSAlertShown()
                    }

                    if active {
                        await send(.testLatency)
                    }
                }

            case .refreshDNSStatus:
                return .run { send in
                    let display = await DNSManager.shared.currentServersDisplay()
                    let active = await DNSManager.shared.isCustomDNSActive()
                    await send(.dnsStatusLoaded(display, active))
                }

            case let .dnsStatusLoaded(dns, active):
                state.currentDNS = dns
                state.isCustomDNSActive = active
                return .none

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
                state.isCustomDNSActive = false
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
                        let latency = await DNSManager.shared.testLatency(server: server)
                        await send(.latencyResult(latency))
                    } else {
                        await send(.latencyResult(nil))
                    }
                }

            case let .latencyResult(ms):
                state.latencyMs = ms
                state.isTestingLatency = false
                return .none

            case let .setApplying(value):
                state.isApplying = value
                return .none
            }
        }
    }
}