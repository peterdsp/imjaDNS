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

        // System-enforced "use this DNS on cellular data" (on-demand rules).
        var cellularEnabled = false
        var cellularProfileID: UUID?

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

    }

    enum Action: BindableAction, Equatable {
        case onAppear
        case loaded(rules: [AutomationRule], profiles: [DNSProfile])
        case cellularLoaded(enabled: Bool, profileID: UUID?)
        case setCellularEnabled(Bool)
        case setCellularProfile(UUID?)
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
                    let cellular = await PersistenceManager.shared.loadCellularDNS()
                    await send(.loaded(rules: rules, profiles: profiles))
                    await send(.cellularLoaded(enabled: cellular.enabled, profileID: cellular.profileID))
                }

            case let .loaded(rules, profiles):
                state.rules = rules
                state.profiles = profiles
                return .none

            case let .cellularLoaded(enabled, profileID):
                state.cellularEnabled = enabled
                state.cellularProfileID = profileID
                return .none

            case let .setCellularEnabled(enabled):
                state.cellularEnabled = enabled
                if enabled && state.cellularProfileID == nil {
                    state.cellularProfileID = state.profiles.first?.id
                }
                return applyCellular(enabled: state.cellularEnabled, profileID: state.cellularProfileID, profiles: state.profiles)

            case let .setCellularProfile(id):
                state.cellularProfileID = id
                if state.cellularEnabled {
                    return applyCellular(enabled: true, profileID: id, profiles: state.profiles)
                }
                return .run { _ in await PersistenceManager.shared.saveCellularDNS(enabled: false, profileID: id) }

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

    private func applyCellular(enabled: Bool, profileID: UUID?, profiles: [DNSProfile]) -> Effect<Action> {
        .run { _ in
            await PersistenceManager.shared.saveCellularDNS(enabled: enabled, profileID: profileID)
            if enabled, let profileID, let profile = profiles.first(where: { $0.id == profileID }) {
                try? await DNSApplyService.applyCellularOnly(profile)
            } else if !enabled {
                try? await DNSApplyService.disable()
            }
        }
    }
}
