import ComposableArchitecture
import Foundation

@Reducer
struct DiagnosticsFeature {
    @ObservableState
    struct State: Equatable {
        var report: DNSDiagnostics.Report?
        var isRunning = false
    }

    enum Action: Equatable {
        case onAppear
        case runTapped
        case reportReady(DNSDiagnostics.Report)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return state.report == nil ? .send(.runTapped) : .none

            case .runTapped:
                guard !state.isRunning else { return .none }
                state.isRunning = true
                return .run { send in
                    let report = await DNSDiagnostics.run()
                    await send(.reportReady(report))
                }

            case let .reportReady(report):
                state.report = report
                state.isRunning = false
                return .none
            }
        }
    }
}
