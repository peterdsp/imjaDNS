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
        var showFirstTimeDNSAlert: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case updateCurrentDNS(String)
        case changeDNS
        case updateNetworkName(String)
        case toggleDNSAlert(Bool)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { send in
                let dns = await DNSManager.shared.getCurrentDNS()
                await send(.updateCurrentDNS(dns))

                if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasShownDNSAlert) {
                    await send(.toggleDNSAlert(true))
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasShownDNSAlert)
                }

                if UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoApplyDNS),
                   let lastUsedDNS = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastUsedDNS) {
                    try? await DNSManager.shared.setServers([lastUsedDNS])
                    await send(.updateCurrentDNS(lastUsedDNS))
                }
            }

        case let .updateCurrentDNS(dns):
            state.currentDNS = dns
            return .none
            
        case let .toggleDNSAlert(value):
            state.showFirstTimeDNSAlert = value
            return .none
            
        case .changeDNS:
            let newDNS = "8.8.8.8"
            return .run { send in
                try? await DNSManager.shared.setServers([newDNS])
                await send(.updateCurrentDNS(newDNS))
                UserDefaults.standard.set(newDNS, forKey: UserDefaultsKeys.lastUsedDNS)
            }

        case let .updateNetworkName(name):
            state.networkName = name
            return .none
        }
    }
}
