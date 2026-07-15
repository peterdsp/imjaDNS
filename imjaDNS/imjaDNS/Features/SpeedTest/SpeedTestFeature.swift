import ComposableArchitecture
import Foundation

@Reducer
struct SpeedTestFeature {
    @ObservableState
    struct State: Equatable {
        var profiles: [DNSProfile] = []
        var results: [UUID: Double] = [:]
        var isTesting: Bool = false
        var currentTestIndex: Int = 0
        var totalTests: Int = 0
        var pastResults: [SpeedTestResult] = []
    }

    enum Action: Equatable {
        case onAppear
        case profilesLoaded([DNSProfile])
        case startTest
        case testResult(UUID, String, String, Double?)
        case testComplete
        case pastResultsLoaded([SpeedTestResult])
        case clearResults
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let profiles = DNSProfileCatalog.builtIn
                    let past = await PersistenceManager.shared.loadSpeedTestResults()
                    await send(.profilesLoaded(profiles))
                    await send(.pastResultsLoaded(past))
                }

            case let .profilesLoaded(profiles):
                state.profiles = profiles
                return .none

            case .startTest:
                state.isTesting = true
                state.results = [:]
                state.currentTestIndex = 0
                state.totalTests = state.profiles.count
                let profiles = state.profiles
                return .run { send in
                    let timeout = await SpeedProbe.adaptiveTimeout()
                    await SpeedProbe.probeConcurrently(profiles, timeout: timeout) { profile, latency in
                        await send(.testResult(profile.id, profile.name, profile.primaryServer, latency))
                    }
                    await send(.testComplete)
                }

            case let .testResult(id, name, server, latency):
                state.currentTestIndex += 1
                if let latency {
                    state.results[id] = latency
                }
                return .run { _ in
                    if let latency {
                        let result = SpeedTestResult(
                            profileName: name,
                            server: server,
                            latencyMs: latency
                        )
                        var existing = await PersistenceManager.shared.loadSpeedTestResults()
                        existing.append(result)
                        await PersistenceManager.shared.saveSpeedTestResults(existing)
                    }
                }

            case .testComplete:
                state.isTesting = false
                return .run { send in
                    let past = await PersistenceManager.shared.loadSpeedTestResults()
                    await send(.pastResultsLoaded(past))
                }

            case let .pastResultsLoaded(results):
                state.pastResults = results
                return .none

            case .clearResults:
                state.results = [:]
                state.pastResults = []
                return .run { _ in
                    await PersistenceManager.shared.saveSpeedTestResults([])
                }
            }
        }
    }
}
