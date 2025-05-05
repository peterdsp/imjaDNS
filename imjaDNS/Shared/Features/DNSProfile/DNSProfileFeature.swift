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
            DNSProfile(name: "Google", servers: ["8.8.8.8", "8.8.4.4"]),
            DNSProfile(name: "Control D", servers: ["76.76.2.0", "76.76.10.0"]),
            DNSProfile(name: "Quad9", servers: ["9.9.9.9", "149.112.112.112"]),
            DNSProfile(name: "OpenDNS Home", servers: ["208.67.222.222", "208.67.220.220"]),
            DNSProfile(name: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"]),
            DNSProfile(name: "AdGuard DNS", servers: ["94.140.14.14", "94.140.15.15"]),
            DNSProfile(name: "CleanBrowsing", servers: ["185.228.168.9", "185.228.169.9"]),
            DNSProfile(name: "Alternate DNS", servers: ["76.76.19.19", "76.223.122.150"])
        ]
        var customDNS: String = ""
    }

    enum Action: Equatable {
        case selectProfile(DNSProfile)
        case updateCustomDNS(String)
        case addCustomDNS
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .selectProfile(profile):
            DNSManager.shared.changeDNS(to: profile.servers.first ?? "")
            return .none

        case let .updateCustomDNS(input):
            state.customDNS = input
            return .none

        case .addCustomDNS:
            let trimmed = state.customDNS.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .none }
            let newProfile = DNSProfile(name: "Custom", servers: [trimmed])
            state.profiles.insert(newProfile, at: 0)
            state.customDNS = ""
            DNSManager.shared.changeDNS(to: trimmed)
            return .none
        }
    }
}
