import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var autoApplyDNS: Bool = false
        var hasCompletedOnboarding: Bool = true
        var showResetAlert: Bool = false
        var appVersion: String = ""
    }

    enum Action: Equatable {
        case onAppear
        case toggleAutoApply(Bool)
        case openDeviceManagement
        case confirmReset
        case cancelReset
        case showResetAlert
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let autoApply = await PersistenceManager.shared.autoApplyDNS
                    await send(.toggleAutoApply(autoApply))
                }

            case let .toggleAutoApply(value):
                state.autoApplyDNS = value
                return .run { _ in
                    await PersistenceManager.shared.setAutoApplyDNS(value)
                }

            case .openDeviceManagement:
                return .run { _ in
                    await MainActor.run {
                        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

            case .showResetAlert:
                state.showResetAlert = true
                return .none

            case .confirmReset:
                state.showResetAlert = false
                return .run { send in
                    try? await DNSManager.shared.disableCustomDNS()
                    await PersistenceManager.shared.saveCustomProfiles([])
                    await PersistenceManager.shared.saveConnectionLog([])
                    await PersistenceManager.shared.saveSpeedTestResults([])
                    await PersistenceManager.shared.saveFavoriteIDs([])
                    await PersistenceManager.shared.saveActiveProfileID(nil)
                    await send(.toggleAutoApply(false))
                }

            case .cancelReset:
                state.showResetAlert = false
                return .none
            }
        }
    }
}