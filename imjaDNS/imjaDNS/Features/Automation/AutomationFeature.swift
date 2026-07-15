import ComposableArchitecture
import Foundation

@Reducer
struct AutomationFeature {
    @ObservableState
    struct State: Equatable {
        var rules: [AutomationRule] = []
        var profiles: [DNSProfile] = []
        var isAddingRule = false
        var draft = Draft()

        struct Draft: Equatable {
            var kind: TriggerKind = .anyWifi
            var ssid = ""
            var startMinute = 8 * 60
            var endMinute = 20 * 60
            var profileID: UUID?   // nil = disable custom DNS

            var trigger: AutomationRule.Trigger {
                switch kind {
                case .anyWifi: return .anyWifi
                case .cellular: return .cellular
                case .ssid: return .ssid(ssid.trimmingCharacters(in: .whitespaces))
                case .schedule: return .schedule(startMinute: startMinute, endMinute: endMinute)
                }
            }

            var isValid: Bool {
                switch kind {
                case .ssid: return !ssid.trimmingCharacters(in: .whitespaces).isEmpty
                default: return true
                }
            }
        }

        enum TriggerKind: String, CaseIterable, Identifiable, Equatable {
            case anyWifi = "Any Wi-Fi"
            case cellular = "Cellular"
            case ssid = "Specific Wi-Fi"
            case schedule = "Schedule"
            var id: String { rawValue }
        }

        func profileName(for id: UUID?) -> String {
            guard let id else { return "Disable DNS" }
            return profiles.first { $0.id == id }?.name ?? "Unknown"
        }
    }

    enum Action: BindableAction, Equatable {
        case onAppear
        case loaded(rules: [AutomationRule], profiles: [DNSProfile])
        case addRuleTapped
        case saveDraft
        case cancelDraft
        case toggleRule(UUID)
        case deleteRule(UUID)
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let rules = await PersistenceManager.shared.loadAutomationRules()
                    let profiles = await ProfileProvider.allProfiles()
                    await send(.loaded(rules: rules, profiles: profiles))
                }

            case let .loaded(rules, profiles):
                state.rules = rules
                state.profiles = profiles
                return .none

            case .addRuleTapped:
                state.draft = State.Draft()
                state.isAddingRule = true
                return .none

            case .cancelDraft:
                state.isAddingRule = false
                return .none

            case .saveDraft:
                guard state.draft.isValid else { return .none }
                state.rules.append(AutomationRule(
                    trigger: state.draft.trigger,
                    profileID: state.draft.profileID
                ))
                state.isAddingRule = false
                return persist(state.rules)

            case let .toggleRule(id):
                if let index = state.rules.firstIndex(where: { $0.id == id }) {
                    state.rules[index].isEnabled.toggle()
                }
                return persist(state.rules)

            case let .deleteRule(id):
                state.rules.removeAll { $0.id == id }
                return persist(state.rules)

            case .binding:
                return .none
            }
        }
    }

    private func persist(_ rules: [AutomationRule]) -> Effect<Action> {
        .run { _ in
            await PersistenceManager.shared.saveAutomationRules(rules)
            await AutomationEngine.shared.evaluate()
        }
    }
}
