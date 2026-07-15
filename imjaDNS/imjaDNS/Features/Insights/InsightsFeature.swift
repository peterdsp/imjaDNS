import ComposableArchitecture
import Foundation

@Reducer
struct InsightsFeature {
    @ObservableState
    struct State: Equatable {
        var results: [SpeedTestResult] = []
        var window: TimeWindow = .week
        var stats: [LatencyAnalytics.ProviderStat] = []
        var series: [LatencyAnalytics.ProviderSeries] = []
        var selectedProviders: Set<String> = []
        var isRefreshing = false
        var fastest: FastestResult?

        struct FastestResult: Equatable {
            let profile: DNSProfile
            let latencyMs: Double
        }
    }

    enum Action: Equatable {
        case onAppear
        case resultsLoaded([SpeedTestResult])
        case setWindow(TimeWindow)
        case toggleProvider(String)
        case refreshFastest
        case fastestLoaded(State.FastestResult?)
        case applyFastest
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let results = await PersistenceManager.shared.loadSpeedTestResults()
                    await send(.resultsLoaded(results))
                }

            case let .resultsLoaded(results):
                state.results = results
                recompute(&state)
                // Default the chart to the four fastest providers.
                if state.selectedProviders.isEmpty {
                    state.selectedProviders = Set(state.stats.prefix(4).map(\.name))
                }
                return .none

            case let .setWindow(window):
                state.window = window
                recompute(&state)
                return .none

            case let .toggleProvider(name):
                if state.selectedProviders.contains(name) {
                    state.selectedProviders.remove(name)
                } else {
                    state.selectedProviders.insert(name)
                }
                return .none

            case .refreshFastest:
                state.isRefreshing = true
                return .run { send in
                    var best: State.FastestResult?
                    for profile in DNSProfileCatalog.builtIn {
                        guard let ms = await DNSManager.shared.testProfileLatency(profile) else { continue }
                        if best == nil || ms < best!.latencyMs {
                            best = State.FastestResult(profile: profile, latencyMs: ms)
                        }
                    }
                    await send(.fastestLoaded(best))
                }

            case let .fastestLoaded(result):
                state.isRefreshing = false
                state.fastest = result
                return .none

            case .applyFastest:
                guard let fastest = state.fastest else { return .none }
                return .run { _ in
                    try? await DNSApplyService.apply(fastest.profile)
                }
            }
        }
    }

    private func recompute(_ state: inout State) {
        let now = Date()
        state.stats = LatencyAnalytics.providerStats(from: state.results, window: state.window, now: now)
        state.series = LatencyAnalytics.series(from: state.results, window: state.window, now: now)
    }
}
