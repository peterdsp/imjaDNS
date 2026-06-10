import Foundation
@preconcurrency import FirebaseRemoteConfig

final class FirebaseManager: @unchecked Sendable {
    static let shared = FirebaseManager()

    private let remoteConfig = RemoteConfig.remoteConfig()

    init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
    }

    func fetchProfiles() async throws -> [DNSProfile] {
        try await remoteConfig.fetchAndActivate()

        let jsonString = remoteConfig["dns_profiles"].stringValue
        guard !jsonString.isEmpty,
              let jsonData = jsonString.data(using: .utf8) else {
            return []
        }

        struct Wrapper: Decodable {
            let profiles: [DNSProfile]
        }

        let wrapper = try JSONDecoder().decode(Wrapper.self, from: jsonData)
        return wrapper.profiles
    }
}
