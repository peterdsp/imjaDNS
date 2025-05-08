//
//  DNSProfileFeature.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import ComposableArchitecture
import Foundation

struct DNSProfileFeature: Reducer {
    struct State: Equatable {
        var profiles: [DNSProfile] = []
        var customDNS: String = ""
        var selectedProfileID: UUID? = nil
        var isLoading: Bool = true
        var hasLoadedOnce: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case profilesLoaded([DNSProfile])
        case selectProfile(DNSProfile)
        case updateCustomDNS(String)
        case addCustomDNS
        case setLoading(Bool)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .onAppear:
            guard !state.hasLoadedOnce else { return .none }
            state.hasLoadedOnce = true
            return .run { send in
                do {
                    var profiles = try await FirebaseManager.shared.fetchProfiles()
                    // Generate UUIDs since Firebase doesn’t provide them
                    profiles = profiles.map { DNSProfile(id: UUID(), name: $0.name, servers: $0.servers) }
                    await send(.profilesLoaded(profiles))
                    await send(.setLoading(false))
                } catch {
                    print("[DNSProfileFeature] Failed to fetch profiles: \(error)")
                    await send(.setLoading(false))
                }
            }

        case let .profilesLoaded(profiles):
            state.profiles = profiles
            if let first = profiles.first {
                state.selectedProfileID = first.id
                return .run { _ in
                    try? await DNSManager.shared.setServers([first.servers])
                }
            }
            return .none

        case let .selectProfile(profile):
            state.selectedProfileID = profile.id
            return .run { _ in
                try? await DNSManager.shared.setServers([profile.servers])
            }

        case let .updateCustomDNS(text):
            state.customDNS = text
            return .none

        case .addCustomDNS:
            let trimmed = state.customDNS.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .none }

            state.profiles.removeAll { $0.name == "Custom" }

            let profile = DNSProfile(id: UUID(), name: "Custom", servers: trimmed)
            state.profiles.insert(profile, at: 0)
            state.customDNS = ""
            state.selectedProfileID = profile.id

            return .run { _ in
                try? await DNSManager.shared.setServers([trimmed])
            }

        case let .setLoading(value):
            state.isLoading = value
            return .none
        }
    }
}
