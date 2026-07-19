import ComposableArchitecture
import Foundation

@Reducer
struct SpeedTestFeature {
    enum Mode: String, Equatable, Sendable { case dns, internet }
    enum InternetPhase: Equatable, Sendable { case idle, ping, download, upload, done }

    @ObservableState
    struct State: Equatable {
        var mode: Mode = .dns

        // DNS latency test
        var profiles: [DNSProfile] = []
        var results: [UUID: Double] = [:]
        var isTesting: Bool = false
        var currentTestIndex: Int = 0
        var totalTests: Int = 0
        var pastResults: [SpeedTestResult] = []

        // Internet bandwidth test
        var internetPhase: InternetPhase = .idle
        var isRunningInternet: Bool = false
        var liveMbps: Double = 0
        var downloadMbps: Double?
        var uploadMbps: Double?
        var pingMs: Double?
        var jitterMs: Double?
        var server: String?
        var scenarios: [ScenarioResult] = []
    }

    enum Action: Equatable {
        case onAppear
        case profilesLoaded([DNSProfile])
        case startTest
        case testResult(UUID, String, String, Double?)
        case testComplete
        case pastResultsLoaded([SpeedTestResult])
        case clearResults
        // Internet
        case setMode(Mode)
        case startInternetTest
        case internetPhaseChanged(InternetPhase)
        case internetLive(Double)
        case internetPing(Double, Double)
        case internetServer(String?)
        case internetDownload(Double)
        case internetComplete(down: Double, up: Double, ping: Double, jitter: Double)
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

            // MARK: - Internet bandwidth test

            case let .setMode(mode):
                state.mode = mode
                return .none

            case .startInternetTest:
                guard !state.isRunningInternet else { return .none }
                state.isRunningInternet = true
                state.liveMbps = 0
                state.downloadMbps = nil
                state.uploadMbps = nil
                state.pingMs = nil
                state.jitterMs = nil
                state.scenarios = []
                state.internetPhase = .ping
                return .run { send in
                    // Internet transfers need more headroom than a DNS probe.
                    let base = await SpeedProbe.adaptiveTimeout()
                    async let colo = InternetSpeedTester.server(timeout: max(6, base))
                    let (ping, jitter) = await InternetSpeedTester.ping(timeout: max(6, base))
                    await send(.internetPing(ping, jitter))
                    await send(.internetServer(colo))

                    await send(.internetPhaseChanged(.download))
                    let down = await InternetSpeedTester.download(timeout: max(12, base * 3)) { mbps in
                        Task { await send(.internetLive(mbps)) }
                    }
                    await send(.internetDownload(down))

                    await send(.internetPhaseChanged(.upload))
                    await send(.internetLive(0))
                    let up = await InternetSpeedTester.upload(timeout: max(12, base * 3)) { mbps in
                        Task { await send(.internetLive(mbps)) }
                    }
                    await send(.internetComplete(down: down, up: up, ping: ping, jitter: jitter))
                }

            case let .internetPhaseChanged(phase):
                state.internetPhase = phase
                return .none

            case let .internetLive(mbps):
                state.liveMbps = mbps
                return .none

            case let .internetPing(ping, jitter):
                state.pingMs = ping
                state.jitterMs = jitter
                return .none

            case let .internetServer(server):
                state.server = server
                return .none

            case let .internetDownload(down):
                state.downloadMbps = down
                return .none

            case let .internetComplete(down, up, ping, jitter):
                state.downloadMbps = down
                state.uploadMbps = up
                state.pingMs = ping
                state.jitterMs = jitter
                state.liveMbps = down
                state.scenarios = InternetScenarios.evaluate(down: down, up: up, ping: ping, jitter: jitter)
                state.internetPhase = .done
                state.isRunningInternet = false
                return .none
            }
        }
    }
}
