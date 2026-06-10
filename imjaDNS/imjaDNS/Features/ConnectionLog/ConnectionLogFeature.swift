import ComposableArchitecture
import Foundation

@Reducer
struct ConnectionLogFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [ConnectionLogEntry] = []
        var isLoading: Bool = true
    }

    enum Action: Equatable {
        case onAppear
        case entriesLoaded([ConnectionLogEntry])
        case clearLog
        case logCleared
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let entries = await PersistenceManager.shared.loadConnectionLog()
                    await send(.entriesLoaded(entries))
                }

            case let .entriesLoaded(entries):
                state.entries = entries.reversed()
                state.isLoading = false
                return .none

            case .clearLog:
                return .run { send in
                    await PersistenceManager.shared.saveConnectionLog([])
                    await send(.logCleared)
                }

            case .logCleared:
                state.entries = []
                return .none
            }
        }
    }
}
