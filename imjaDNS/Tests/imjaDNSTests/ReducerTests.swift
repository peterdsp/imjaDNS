import Testing
import ComposableArchitecture
import Foundation
@testable import imjaDNS

// MARK: - HomeFeature Tests

struct HomeFeatureTests {
    @Test func initialState() {
        let state = HomeFeature.State()
        #expect(state.currentDNS == "Loading...")
        #expect(state.isCustomDNSActive == false)
        #expect(state.networkType == "Checking...")
        #expect(state.showFirstTimeAlert == false)
        #expect(state.isApplying == false)
        #expect(state.errorMessage == nil)
        #expect(state.latencyMs == nil)
    }

    @Test func dnsStatusLoaded() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.dnsStatusLoaded("1.1.1.1", true))
        #expect(store.state.currentDNS == "1.1.1.1")
        #expect(store.state.isCustomDNSActive == true)
    }

    @Test func networkUpdated() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.networkUpdated("Wi-Fi", "wifi"))
        #expect(store.state.networkType == "Wi-Fi")
        #expect(store.state.networkIcon == "wifi")
    }

    @Test func toggleFirstTimeAlert() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleFirstTimeAlert(true))
        #expect(store.state.showFirstTimeAlert == true)

        await store.send(.toggleFirstTimeAlert(false))
        #expect(store.state.showFirstTimeAlert == false)
    }

    @Test func showAndDismissError() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.showError("Something went wrong"))
        #expect(store.state.errorMessage == "Something went wrong")
        #expect(store.state.isApplying == false)

        await store.send(.dismissError)
        #expect(store.state.errorMessage == nil)
    }

    @Test func latencyResult() async {
        let store = TestStore(initialState: HomeFeature.State(isTestingLatency: true)) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.latencyResult(25.5))
        #expect(store.state.latencyMs == 25.5)
        #expect(store.state.isTestingLatency == false)
    }

    @Test func latencyResultNil() async {
        let store = TestStore(initialState: HomeFeature.State(isTestingLatency: true)) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.latencyResult(nil))
        #expect(store.state.latencyMs == nil)
        #expect(store.state.isTestingLatency == false)
    }

    @Test func dnsDisconnected() async {
        let store = TestStore(initialState: HomeFeature.State(
            currentDNS: "1.1.1.1",
            isCustomDNSActive: true,
            activeProfileName: "Cloudflare",
            latencyMs: 15.0
        )) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.dnsDisconnected)
        #expect(store.state.currentDNS == "System Default")
        #expect(store.state.isCustomDNSActive == false)
        #expect(store.state.activeProfileName == nil)
        #expect(store.state.latencyMs == nil)
    }

    @Test func setApplying() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.setApplying(true))
        #expect(store.state.isApplying == true)
    }
}

// MARK: - DNSProfileFeature Tests

struct DNSProfileFeatureTests {
    @Test func initialState() {
        let state = DNSProfileFeature.State()
        #expect(state.allProfiles.isEmpty)
        #expect(state.customProfiles.isEmpty)
        #expect(state.selectedCategory == nil)
        #expect(state.activeProfileID == nil)
        #expect(state.isLoading == true)
        #expect(state.hasLoadedOnce == false)
        #expect(state.showAddCustomSheet == false)
    }

    @Test func selectCategory() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.selectCategory(.privacy))
        #expect(store.state.selectedCategory == .privacy)

        await store.send(.selectCategory(nil))
        #expect(store.state.selectedCategory == nil)
    }

    @Test func profilesLoaded() async {
        let profiles = [
            DNSProfile(name: "Test1", servers: ["1.1.1.1"], isBuiltIn: true),
            DNSProfile(name: "Test2", servers: ["8.8.8.8"], isBuiltIn: true),
        ]
        let custom = [DNSProfile(name: "Custom", servers: ["9.9.9.9"])]

        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.profilesLoaded(profiles, custom))
        #expect(store.state.allProfiles.count == 3)
        #expect(store.state.customProfiles.count == 1)
        #expect(store.state.isLoading == false)
    }

    @Test func profileApplied() async {
        let profileID = UUID()
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.profileApplied(profileID))
        #expect(store.state.activeProfileID == profileID)
    }

    @Test func toggleFavorite() async {
        let profile = DNSProfile(name: "Test", servers: ["1.1.1.1"], isFavorite: false, isBuiltIn: true)
        let store = TestStore(initialState: DNSProfileFeature.State(allProfiles: [profile])) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleFavorite(profile))
        #expect(store.state.allProfiles[0].isFavorite == true)
    }

    @Test func updateCustomName() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.updateCustomName("My DNS"))
        #expect(store.state.customName == "My DNS")
    }

    @Test func updateCustomServers() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.updateCustomServers("1.1.1.1, 8.8.8.8"))
        #expect(store.state.customServers == "1.1.1.1, 8.8.8.8")
    }

    @Test func toggleAddCustomSheet() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleAddCustomSheet)
        #expect(store.state.showAddCustomSheet == true)

        await store.send(.toggleAddCustomSheet)
        #expect(store.state.showAddCustomSheet == false)
    }

    @Test func addCustomProfileEmptyName() async {
        let store = TestStore(initialState: DNSProfileFeature.State(
            customName: "",
            customServers: "1.1.1.1"
        )) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.addCustomProfile)
        #expect(store.state.errorMessage == "Please enter a profile name")
    }

    @Test func addCustomProfileEmptyServers() async {
        let store = TestStore(initialState: DNSProfileFeature.State(
            customName: "Test",
            customServers: ""
        )) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.addCustomProfile)
        #expect(store.state.errorMessage == "Please enter at least one DNS server")
    }

    @Test func addCustomProfileInvalidServer() async {
        let store = TestStore(initialState: DNSProfileFeature.State(
            customName: "Test",
            customServers: "not.an.ip.addr"
        )) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.addCustomProfile)
        #expect(store.state.errorMessage == "Invalid server address: not.an.ip.addr")
    }

    @Test func showAndDismissError() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.showError("Test error"))
        #expect(store.state.errorMessage == "Test error")

        await store.send(.dismissError)
        #expect(store.state.errorMessage == nil)
    }

    @Test func setApplying() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.setApplying(true))
        #expect(store.state.isApplying == true)
    }

    @Test func filteredProfilesByCategory() {
        let profiles = [
            DNSProfile(name: "P1", servers: ["1.1.1.1"], category: .privacy),
            DNSProfile(name: "P2", servers: ["8.8.8.8"], category: .speed),
            DNSProfile(name: "P3", servers: ["9.9.9.9"], category: .privacy),
        ]

        var state = DNSProfileFeature.State(allProfiles: profiles)
        state.selectedCategory = .privacy
        #expect(state.filteredProfiles.count == 2)
        #expect(state.filteredProfiles.allSatisfy { $0.category == .privacy })
    }

    @Test func filteredProfilesNilCategory() {
        let profiles = [
            DNSProfile(name: "P1", servers: ["1.1.1.1"], category: .privacy),
            DNSProfile(name: "P2", servers: ["8.8.8.8"], category: .speed),
        ]

        var state = DNSProfileFeature.State(allProfiles: profiles)
        state.selectedCategory = nil
        #expect(state.filteredProfiles.count == 2)
    }

    @Test func favoriteProfiles() {
        let profiles = [
            DNSProfile(name: "P1", servers: ["1.1.1.1"], isFavorite: true),
            DNSProfile(name: "P2", servers: ["8.8.8.8"], isFavorite: false),
            DNSProfile(name: "P3", servers: ["9.9.9.9"], isFavorite: true),
        ]

        let state = DNSProfileFeature.State(allProfiles: profiles)
        #expect(state.favoriteProfiles.count == 2)
    }

    @Test func activeProfileLoaded() async {
        let id = UUID()
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.activeProfileLoaded(id))
        #expect(store.state.activeProfileID == id)
    }

    @Test func speedTestResult() async {
        let id = UUID()
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.speedTestResult(id, 15.0))
        #expect(store.state.latencyResults[id] == 15.0)
    }

    @Test func setTestingSpeed() async {
        let store = TestStore(initialState: DNSProfileFeature.State()) {
            DNSProfileFeature()
        }
        store.exhaustivity = .off

        await store.send(.setTestingSpeed(true))
        #expect(store.state.isTestingSpeed == true)
    }
}

// MARK: - ConnectionLogFeature Tests

struct ConnectionLogFeatureTests {
    @Test func initialState() {
        let state = ConnectionLogFeature.State()
        #expect(state.entries.isEmpty)
        #expect(state.isLoading == true)
    }

    @Test func entriesLoaded() async {
        let entries = [
            ConnectionLogEntry(profileName: "Test", servers: ["1.1.1.1"], action: .applied),
            ConnectionLogEntry(profileName: "Test2", servers: ["8.8.8.8"], action: .removed),
        ]

        let store = TestStore(initialState: ConnectionLogFeature.State()) {
            ConnectionLogFeature()
        }
        store.exhaustivity = .off

        await store.send(.entriesLoaded(entries))
        #expect(store.state.entries.count == 2)
        #expect(store.state.isLoading == false)
    }

    @Test func logCleared() async {
        let entries = [
            ConnectionLogEntry(profileName: "Test", servers: ["1.1.1.1"], action: .applied),
        ]

        let store = TestStore(initialState: ConnectionLogFeature.State(entries: entries)) {
            ConnectionLogFeature()
        }
        store.exhaustivity = .off

        await store.send(.logCleared)
        #expect(store.state.entries.isEmpty)
    }
}

// MARK: - SpeedTestFeature Tests

struct SpeedTestFeatureTests {
    @Test func initialState() {
        let state = SpeedTestFeature.State()
        #expect(state.profiles.isEmpty)
        #expect(state.results.isEmpty)
        #expect(state.isTesting == false)
        #expect(state.currentTestIndex == 0)
    }

    @Test func profilesLoaded() async {
        let profiles = DNSProfileCatalog.builtIn
        let store = TestStore(initialState: SpeedTestFeature.State()) {
            SpeedTestFeature()
        }
        store.exhaustivity = .off

        await store.send(.profilesLoaded(profiles))
        #expect(store.state.profiles.count == profiles.count)
    }

    @Test func testResultRecorded() async {
        let id = UUID()
        let store = TestStore(initialState: SpeedTestFeature.State(
            isTesting: true,
            totalTests: 5
        )) {
            SpeedTestFeature()
        }
        store.exhaustivity = .off

        await store.send(.testResult(id, "Test", "1.1.1.1", 15.0))
        #expect(store.state.currentTestIndex == 1)
        #expect(store.state.results[id] == 15.0)
    }

    @Test func testComplete() async {
        let store = TestStore(initialState: SpeedTestFeature.State(isTesting: true)) {
            SpeedTestFeature()
        }
        store.exhaustivity = .off

        await store.send(.testComplete)
        #expect(store.state.isTesting == false)
    }

    @Test func pastResultsLoaded() async {
        let results = [
            SpeedTestResult(profileName: "Test", server: "1.1.1.1", latencyMs: 15.0),
        ]

        let store = TestStore(initialState: SpeedTestFeature.State()) {
            SpeedTestFeature()
        }
        store.exhaustivity = .off

        await store.send(.pastResultsLoaded(results))
        #expect(store.state.pastResults.count == 1)
    }

    @Test func clearResults() async {
        let store = TestStore(initialState: SpeedTestFeature.State(
            results: [UUID(): 15.0],
            pastResults: [SpeedTestResult(profileName: "T", server: "1.1.1.1", latencyMs: 10)]
        )) {
            SpeedTestFeature()
        }
        store.exhaustivity = .off

        await store.send(.clearResults)
        #expect(store.state.results.isEmpty)
        #expect(store.state.pastResults.isEmpty)
    }
}

// MARK: - SettingsFeature Tests

struct SettingsFeatureTests {
    @Test func initialState() {
        let state = SettingsFeature.State()
        #expect(state.autoApplyDNS == false)
        #expect(state.showResetAlert == false)
    }

    @Test func toggleAutoApply() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleAutoApply(true))
        #expect(store.state.autoApplyDNS == true)
    }

    @Test func showResetAlert() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off

        await store.send(.showResetAlert)
        #expect(store.state.showResetAlert == true)
    }

    @Test func cancelReset() async {
        let store = TestStore(initialState: SettingsFeature.State(showResetAlert: true)) {
            SettingsFeature()
        }
        store.exhaustivity = .off

        await store.send(.cancelReset)
        #expect(store.state.showResetAlert == false)
    }
}
