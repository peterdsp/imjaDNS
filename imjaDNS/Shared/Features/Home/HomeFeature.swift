//
//  HomeFeature.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import ComposableArchitecture

struct HomeFeature: Reducer {
    struct State: Equatable {
        var currentDNS: String = DNSManager.shared.getCurrentDNS()
    }

    enum Action: Equatable {
        case changeDNS
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .changeDNS:
            let newDNS = "8.8.8.8" // Example change
            DNSManager.shared.changeDNS(to: newDNS)
            state.currentDNS = newDNS
            return .none
        }
    }
}
