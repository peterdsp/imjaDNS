//
//  DNSProfileFeature.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import ComposableArchitecture

struct DNSProfileFeature: Reducer {
    struct State: Equatable {
        var profiles: [DNSProfile] = [
            DNSProfile(name: "Privacy Mode", servers: ["1.1.1.1"]),
            DNSProfile(name: "Speed", servers: ["8.8.8.8"]),
            DNSProfile(name: "Ad-Blocking", servers: ["94.140.14.14"])
        ]
    }

    enum Action: Equatable {
        case selectProfile(DNSProfile)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .selectProfile(profile):
            DNSManager.shared.changeDNS(to: profile.servers.first ?? "")
            return .none
        }
    }
}
