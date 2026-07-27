import ComposableArchitecture
import Foundation

@Reducer
struct SitesFeature {
    @ObservableState
    struct State: Equatable {
        var customSites: [Website] = []
        var favoriteDomains: Set<String> = []
        var searchText: String = ""
        var selectedCategory: SiteCategory? = nil
        var favoritesOnly: Bool = false
        /// Latest check result per domain.
        var results: [String: SiteCheckResult] = [:]
        var isCheckingAll: Bool = false

        // Add-custom sheet
        var showAddSheet: Bool = false
        var newName: String = ""
        var newDomain: String = ""

        /// Built-in directory plus the user's custom sites.
        var allSites: [Website] { SiteDirectory.builtIn + customSites }

        /// The list to show, after search / category / favorites filtering.
        var visibleSites: [Website] {
            let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            return allSites.filter { site in
                if favoritesOnly && !favoriteDomains.contains(site.domain) { return false }
                if let selectedCategory, site.category != selectedCategory { return false }
                if !query.isEmpty {
                    return site.name.lowercased().contains(query) || site.domain.lowercased().contains(query)
                }
                return true
            }
        }

        /// A trimmed, lowercased domain from the add form (strips scheme/paths).
        var normalizedNewDomain: String {
            var d = newDomain.trimmingCharacters(in: .whitespaces).lowercased()
            if let range = d.range(of: "://") { d = String(d[range.upperBound...]) }
            if let slash = d.firstIndex(of: "/") { d = String(d[..<slash]) }
            return d
        }

        var canAddCustom: Bool {
            let d = normalizedNewDomain
            return d.contains(".") && !d.contains(" ") && !allSites.contains { $0.domain == d }
        }
    }

    enum Action: Equatable {
        case onAppear
        case loaded([Website], Set<String>)
        case searchChanged(String)
        case categorySelected(SiteCategory?)
        case favoritesOnlyToggled(Bool)
        case toggleFavorite(String)
        case checkSite(Website)
        case checkResult(String, SiteCheckResult)
        case checkVisible
        case checkAllFinished
        // Add custom
        case setShowAddSheet(Bool)
        case newNameChanged(String)
        case newDomainChanged(String)
        case addCustom
        case deleteCustom(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let customs = await PersistenceManager.shared.loadCustomSites()
                    let favorites = await PersistenceManager.shared.loadFavoriteSiteDomains()
                    await send(.loaded(customs, favorites))
                }

            case let .loaded(customs, favorites):
                state.customSites = customs
                state.favoriteDomains = favorites
                return .none

            case let .searchChanged(text):
                state.searchText = text
                return .none

            case let .categorySelected(category):
                state.selectedCategory = category
                return .none

            case let .favoritesOnlyToggled(on):
                state.favoritesOnly = on
                return .none

            case let .toggleFavorite(domain):
                if state.favoriteDomains.contains(domain) {
                    state.favoriteDomains.remove(domain)
                } else {
                    state.favoriteDomains.insert(domain)
                }
                return .run { [favorites = state.favoriteDomains] _ in
                    await PersistenceManager.shared.saveFavoriteSiteDomains(favorites)
                }

            case let .checkSite(site):
                state.results[site.domain, default: SiteCheckResult()].phase = .checking
                return .run { send in
                    let result = await SiteChecker.check(site)
                    await send(.checkResult(site.domain, result))
                }

            case let .checkResult(domain, result):
                state.results[domain] = result
                return .none

            case .checkVisible:
                guard !state.isCheckingAll else { return .none }
                state.isCheckingAll = true
                let sites = state.visibleSites
                for site in sites {
                    state.results[site.domain, default: SiteCheckResult()].phase = .checking
                }
                return .run { send in
                    await withTaskGroup(of: (String, SiteCheckResult).self) { group in
                        for site in sites {
                            group.addTask { (site.domain, await SiteChecker.check(site)) }
                        }
                        for await (domain, result) in group {
                            await send(.checkResult(domain, result))
                        }
                    }
                    await send(.checkAllFinished)
                }

            case .checkAllFinished:
                state.isCheckingAll = false
                return .none

            case let .setShowAddSheet(show):
                state.showAddSheet = show
                if !show {
                    state.newName = ""
                    state.newDomain = ""
                }
                return .none

            case let .newNameChanged(text):
                state.newName = text
                return .none

            case let .newDomainChanged(text):
                state.newDomain = text
                return .none

            case .addCustom:
                guard state.canAddCustom else { return .none }
                let domain = state.normalizedNewDomain
                let name = state.newName.trimmingCharacters(in: .whitespaces).isEmpty
                    ? domain
                    : state.newName.trimmingCharacters(in: .whitespaces)
                let site = Website(name: name, domain: domain, category: .custom, isCustom: true)
                state.customSites.append(site)
                state.favoriteDomains.insert(domain)
                state.showAddSheet = false
                state.newName = ""
                state.newDomain = ""
                return .run { [customs = state.customSites, favorites = state.favoriteDomains] _ in
                    await PersistenceManager.shared.saveCustomSites(customs)
                    await PersistenceManager.shared.saveFavoriteSiteDomains(favorites)
                }

            case let .deleteCustom(domain):
                state.customSites.removeAll { $0.domain == domain }
                state.favoriteDomains.remove(domain)
                state.results[domain] = nil
                return .run { [customs = state.customSites, favorites = state.favoriteDomains] _ in
                    await PersistenceManager.shared.saveCustomSites(customs)
                    await PersistenceManager.shared.saveFavoriteSiteDomains(favorites)
                }
            }
        }
    }
}
