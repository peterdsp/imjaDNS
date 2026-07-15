import SwiftUI
import ComposableArchitecture
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        return true
    }
}

@main
struct imjaDNSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    private let homeStore = Store(initialState: HomeFeature.State()) {
        HomeFeature()
    }
    private let profileStore = Store(initialState: DNSProfileFeature.State()) {
        DNSProfileFeature()
    }
    private let speedTestStore = Store(initialState: SpeedTestFeature.State()) {
        SpeedTestFeature()
    }
    private let insightsStore = Store(initialState: InsightsFeature.State()) {
        InsightsFeature()
    }
    private let logStore = Store(initialState: ConnectionLogFeature.State()) {
        ConnectionLogFeature()
    }
    private let settingsStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    private let automationStore = Store(initialState: AutomationFeature.State()) {
        AutomationFeature()
    }
    private let diagnosticsStore = Store(initialState: DiagnosticsFeature.State()) {
        DiagnosticsFeature()
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            NavigationStack {
                HomeView(store: homeStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                DiagnosticsView(store: diagnosticsStore)
                            } label: {
                                Image(systemName: "stethoscope")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "shield.checkered")
            }

            NavigationStack {
                DNSProfileView(store: profileStore)
            }
            .tabItem {
                Label("Profiles", systemImage: "list.bullet.rectangle.fill")
            }

            NavigationStack {
                SpeedTestView(store: speedTestStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                InsightsView(store: insightsStore)
                            } label: {
                                Image(systemName: "chart.xyaxis.line")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Speed Test", systemImage: "gauge.with.dots.needle.67percent")
            }

            NavigationStack {
                ConnectionLogView(store: logStore)
            }
            .tabItem {
                Label("Log", systemImage: "clock.fill")
            }

            NavigationStack {
                SettingsView(store: settingsStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                AutomationView(store: automationStore)
                            } label: {
                                Image(systemName: "bolt.badge.clock")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(Color(hex: "00D2FF"))
        .onAppear {
            profileStore.send(.onAppear)
            AutomationEngine.shared.start()
        }
    }
}
