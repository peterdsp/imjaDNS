import ComposableArchitecture
import Foundation

@Reducer
struct ShareSyncFeature {
    @ObservableState
    struct State: Equatable {
        var customProfiles: [DNSProfile] = []
        var syncEnabled = false
        var message: String?
    }

    enum Action: Equatable {
        case onAppear
        case loaded(profiles: [DNSProfile], syncEnabled: Bool)
        case setSync(Bool)
        case importText(String)      // from QR or file (JSON string)
        case importData(Data)        // from file
        case imported(Int)
        case importFailed
        case dismissMessage
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let profiles = await PersistenceManager.shared.loadCustomProfiles()
                    let enabled = await MainActor.run { CloudSyncManager.shared.isEnabled }
                    await send(.loaded(profiles: profiles, syncEnabled: enabled))
                }

            case let .loaded(profiles, enabled):
                state.customProfiles = profiles
                state.syncEnabled = enabled
                return .none

            case let .setSync(enabled):
                state.syncEnabled = enabled
                return .run { _ in
                    await MainActor.run { CloudSyncManager.shared.isEnabled = enabled }
                }

            case let .importText(text):
                guard let data = text.data(using: .utf8) else { return .send(.importFailed) }
                return .send(.importData(data))

            case let .importData(data):
                return .run { send in
                    guard let decoded = try? ProfileTransfer.decode(data) else {
                        await send(.importFailed); return
                    }
                    let sanitized = ProfileTransfer.sanitize(decoded)
                    guard !sanitized.isEmpty else { await send(.importFailed); return }

                    var existing = await PersistenceManager.shared.loadCustomProfiles()
                    existing.append(contentsOf: sanitized)
                    await PersistenceManager.shared.saveCustomProfiles(existing)
                    await MainActor.run {
                        if CloudSyncManager.shared.isEnabled {
                            Task { await CloudSyncManager.shared.pushLocalToCloud() }
                        }
                    }
                    await send(.imported(sanitized.count))
                }

            case let .imported(count):
                state.message = "Imported \(count) profile\(count == 1 ? "" : "s")."
                return .run { send in
                    let profiles = await PersistenceManager.shared.loadCustomProfiles()
                    let enabled = await MainActor.run { CloudSyncManager.shared.isEnabled }
                    await send(.loaded(profiles: profiles, syncEnabled: enabled))
                }

            case .importFailed:
                state.message = "That file or code didn't contain a valid imjaDNS profile."
                return .none

            case .dismissMessage:
                state.message = nil
                return .none
            }
        }
    }
}
