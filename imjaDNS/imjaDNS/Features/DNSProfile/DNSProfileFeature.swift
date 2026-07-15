import ComposableArchitecture
import Foundation

@Reducer
struct DNSProfileFeature {
    @ObservableState
    struct State: Equatable {
        var allProfiles: [DNSProfile] = []
        var customProfiles: [DNSProfile] = []
        var selectedCategory: DNSCategory? = nil
        var activeProfileID: UUID? = nil
        var isLoading: Bool = true
        var hasLoadedOnce: Bool = false
        var isApplying: Bool = false
        var errorMessage: String? = nil
        var successMessage: String? = nil

        // Custom DNS input
        var customName: String = ""
        var customServers: String = ""
        var showAddCustomSheet: Bool = false

        // Speed test
        var latencyResults: [UUID: Double] = [:]
        var isTestingSpeed: Bool = false

        var filteredProfiles: [DNSProfile] {
            guard let category = selectedCategory else { return allProfiles }
            return allProfiles.filter { $0.category == category }
        }

        var favoriteProfiles: [DNSProfile] {
            allProfiles.filter { $0.isFavorite }
        }

        var categories: [DNSCategory] {
            Array(Set(allProfiles.map(\.category))).sorted { $0.rawValue < $1.rawValue }
        }
    }

    enum Action: Equatable {
        case onAppear
        case profilesLoaded([DNSProfile], [DNSProfile])
        case selectCategory(DNSCategory?)
        case applyProfile(DNSProfile)
        case profileApplied(UUID)
        case removeProfile(DNSProfile)
        case toggleFavorite(DNSProfile)
        case showError(String)
        case showSuccess(String)
        case dismissError
        case dismissSuccess
        case setApplying(Bool)

        // Custom DNS
        case updateCustomName(String)
        case updateCustomServers(String)
        case toggleAddCustomSheet
        case addCustomProfile
        case deleteCustomProfile(DNSProfile)

        // Speed test
        case testAllSpeeds
        case speedTestResult(UUID, Double?)
        case setTestingSpeed(Bool)

        // Reload
        case reloadProfiles

        // Active profile loaded
        case activeProfileLoaded(UUID?)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasLoadedOnce else { return .none }
                state.hasLoadedOnce = true
                return .run { send in
                    let customProfiles = await PersistenceManager.shared.loadCustomProfiles()
                    let favoriteIDs = await PersistenceManager.shared.loadFavoriteIDs()
                    let activeID = await PersistenceManager.shared.loadActiveProfileID()

                    var builtIn = DNSProfileCatalog.builtIn.map { profile -> DNSProfile in
                        var p = profile
                        p.isFavorite = favoriteIDs.contains(p.id)
                        return p
                    }

                    do {
                        let remote = try await FirebaseManager.shared.fetchProfiles()
                        let remoteNames = Set(remote.map(\.name))
                        builtIn = builtIn.filter { !remoteNames.contains($0.name) }
                        builtIn.append(contentsOf: remote)
                    } catch {
                        // Silently use built-in catalog if Firebase fails
                    }

                    await send(.profilesLoaded(builtIn, customProfiles))
                    await send(.activeProfileLoaded(activeID))
                }

            case let .profilesLoaded(builtIn, custom):
                state.allProfiles = builtIn + custom
                state.customProfiles = custom
                state.isLoading = false
                return .none

            case let .activeProfileLoaded(id):
                state.activeProfileID = id
                return .none

            case let .selectCategory(category):
                state.selectedCategory = category
                return .none

            case let .applyProfile(profile):
                state.isApplying = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        try await DNSApplyService.apply(profile)

                        await send(.profileApplied(profile.id))
                        await send(.showSuccess("\(profile.name) activated"))
                    } catch {
                        let entry = ConnectionLogEntry(
                            profileName: profile.name,
                            servers: profile.servers,
                            action: .failed
                        )
                        var log = await PersistenceManager.shared.loadConnectionLog()
                        log.append(entry)
                        await PersistenceManager.shared.saveConnectionLog(log)

                        await send(.showError(error.localizedDescription))
                    }
                    await send(.setApplying(false))
                }

            case let .profileApplied(id):
                state.activeProfileID = id
                return .none

            case let .removeProfile(profile):
                guard !profile.isBuiltIn else { return .none }
                state.allProfiles.removeAll { $0.id == profile.id }
                state.customProfiles.removeAll { $0.id == profile.id }
                return .run { [custom = state.customProfiles] _ in
                    await PersistenceManager.shared.saveCustomProfiles(custom)
                }

            case let .toggleFavorite(profile):
                if let index = state.allProfiles.firstIndex(where: { $0.id == profile.id }) {
                    state.allProfiles[index].isFavorite.toggle()
                }
                return .run { [profiles = state.allProfiles] _ in
                    let favoriteIDs = Set(profiles.filter(\.isFavorite).map(\.id))
                    await PersistenceManager.shared.saveFavoriteIDs(favoriteIDs)
                }

            case let .showError(message):
                state.errorMessage = message
                return .none

            case let .showSuccess(message):
                state.successMessage = message
                return .run { send in
                    try? await Task.sleep(for: .seconds(2))
                    await send(.dismissSuccess)
                }

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .dismissSuccess:
                state.successMessage = nil
                return .none

            case let .setApplying(value):
                state.isApplying = value
                return .none

            // Custom DNS
            case let .updateCustomName(name):
                state.customName = name
                return .none

            case let .updateCustomServers(servers):
                state.customServers = servers
                return .none

            case .toggleAddCustomSheet:
                state.showAddCustomSheet.toggle()
                if !state.showAddCustomSheet {
                    state.customName = ""
                    state.customServers = ""
                }
                return .none

            case .addCustomProfile:
                let name = state.customName.trimmingCharacters(in: .whitespacesAndNewlines)
                let serversRaw = state.customServers.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !name.isEmpty else {
                    state.errorMessage = "Please enter a profile name"
                    return .none
                }

                let servers = serversRaw
                    .components(separatedBy: CharacterSet(charactersIn: ", \n"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                guard !servers.isEmpty else {
                    state.errorMessage = "Please enter at least one DNS server"
                    return .none
                }

                for server in servers {
                    guard DNSValidation.isValidDNSServer(server) else {
                        state.errorMessage = "Invalid server address: \(server)"
                        return .none
                    }
                }

                let profile = DNSProfile(
                    name: name,
                    servers: servers,
                    category: .custom,
                    description: "Custom DNS profile"
                )

                state.allProfiles.append(profile)
                state.customProfiles.append(profile)
                state.showAddCustomSheet = false
                state.customName = ""
                state.customServers = ""

                return .run { [custom = state.customProfiles] _ in
                    await PersistenceManager.shared.saveCustomProfiles(custom)
                }

            case let .deleteCustomProfile(profile):
                state.allProfiles.removeAll { $0.id == profile.id }
                state.customProfiles.removeAll { $0.id == profile.id }
                return .run { [custom = state.customProfiles] _ in
                    await PersistenceManager.shared.saveCustomProfiles(custom)
                }

            // Speed test
            case .testAllSpeeds:
                state.isTestingSpeed = true
                state.latencyResults = [:]
                let profiles = state.allProfiles
                return .run { send in
                    for profile in profiles {
                        let latency = await DNSManager.shared.testProfileLatency(profile)
                        await send(.speedTestResult(profile.id, latency))
                    }
                    await send(.setTestingSpeed(false))
                }

            case let .speedTestResult(id, latency):
                if let latency {
                    state.latencyResults[id] = latency
                }
                return .none

            case let .setTestingSpeed(value):
                state.isTestingSpeed = value
                return .none

            case .reloadProfiles:
                state.isLoading = true
                state.hasLoadedOnce = false
                return .send(.onAppear)
            }
        }
    }
}
