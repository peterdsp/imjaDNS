//
//  FirebaseManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 07/05/2025.
//

import Foundation
import FirebaseRemoteConfig

final class FirebaseManager {
    static let shared = FirebaseManager()
    private let remoteConfig = RemoteConfig.remoteConfig()

    init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0 // Always fetch fresh during development
        remoteConfig.configSettings = settings
    }

    func fetchProfiles() async throws -> [DNSProfile] {

        // Fetch and activate
        try await remoteConfig.fetchAndActivate()

        // Get the string value
        let jsonString = remoteConfig["dns_profiles"].stringValue
        guard !jsonString.isEmpty else {
            print("[FirebaseManager] Missing or empty 'dns_profiles'")
            return []
        }

        // Decode JSON
        struct Wrapper: Decodable {
            let profiles: [DNSProfile]
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("[FirebaseManager] Failed to convert string to data")
            return []
        }

        do {
            let wrapper = try JSONDecoder().decode(Wrapper.self, from: jsonData)
            return wrapper.profiles
        } catch {
            print("[FirebaseManager] JSON decode error: \(error)")
            return []
        }
    }
}
