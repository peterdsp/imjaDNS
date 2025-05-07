//
//  HomeFeature.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import ComposableArchitecture
import Foundation

struct HomeFeature: Reducer {
    struct State: Equatable {
        var currentDNS: String = "Loading..."
        var networkName: String = "..."
        var showLocationAlert: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case updateCurrentDNS(String)
        case changeDNS
        case updateNetworkName(String)
        case toggleLocationAlert(Bool)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { send in
                let dns = await DNSManager.shared.getCurrentDNS()
                await send(.updateCurrentDNS(dns))

                if UserDefaults.standard.bool(forKey: "autoApplyDNS") {
                    // Automatically reapply last used DNS if stored
                    if let lastUsedDNS = UserDefaults.standard.string(forKey: "lastUsedDNS") {
                        DNSManager.shared.changeDNS(to: lastUsedDNS)
                        await send(.updateCurrentDNS(lastUsedDNS))
                    }
                }
            }

        case let .updateCurrentDNS(dns):
            state.currentDNS = dns
            return .none

        case .changeDNS:
            let newDNS = "8.8.8.8"
            DNSManager.shared.changeDNS(to: newDNS)
            state.currentDNS = newDNS
            return .none

        case let .updateNetworkName(name):
            state.networkName = name
            return .none

        case let .toggleLocationAlert(show):
            state.showLocationAlert = show
            return .none
        }
    }
}
