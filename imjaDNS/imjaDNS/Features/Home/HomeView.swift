import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    @Binding var selectedTab: AppTab
    @ObservedObject private var network = NetworkMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusSection
                if store.isCustomDNSActive {
                    latencyCard
                } else if store.dnsStatus == .off {
                    unprotectedPromptCard
                }
                networkInfoCard
                speedSummaryCard
                if !store.recentActivity.isEmpty {
                    recentActivityCard
                }
                quickActionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("imjaDNS")
        .onAppear { store.send(.onAppear) }
        .onChange(of: network.connectionType) { _, newValue in
            store.send(.networkUpdated(newValue.rawValue, newValue.icon))
        }
        .alert(
            "Enable DNS Configuration",
            isPresented: $store.showFirstTimeAlert.sending(\.toggleFirstTimeAlert)
        ) {
            Button("Open Settings") { openDNSSettings() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("To activate DNS profiles, go to:\n\nSettings → General → VPN & Device Management → DNS\n\nThen select imjaDNS.")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.dismissError) } }
            )
        ) {
            Button("OK") { store.send(.dismissError) }
        } message: {
            if let msg = store.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            StatusOrb(isActive: store.isCustomDNSActive, size: 130)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text(LocalizedStringKey(statusTitle))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(statusStyle)

                // "System Default" / "Loading…" localize; server IPs have no
                // catalog entry and pass through unchanged.
                Text(LocalizedStringKey(store.currentDNS))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let name = store.activeProfileName {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accentGradient)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
            }

            if store.dnsStatus == .installedNotEnabled {
                notEnabledCard
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Live DNS latency

    /// The active resolver's round-trip latency with a quality bar and a
    /// re-test control — the "is my DNS actually fast right now" glance.
    private var latencyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("DNS latency", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if store.isTestingLatency {
                        ProgressView().controlSize(.mini)
                    } else {
                        Button {
                            store.send(.testLatency)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.latencyMs.map { "\(Int($0.rounded()))" } ?? "–")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(latencyColor(store.latencyMs))
                    Text("ms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(LocalizedStringKey(latencyQuality(store.latencyMs)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(latencyColor(store.latencyMs))
                }

                latencyQualityBar(store.latencyMs)
            }
        }
    }

    private func latencyQualityBar(_ ms: Double?) -> some View {
        // 0 ms → full, 200 ms+ → empty.
        let fill = ms.map { max(0.05, min(1, 1 - $0 / 200)) } ?? 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(latencyColor(ms))
                    .frame(width: geo.size.width * fill)
            }
        }
        .frame(height: 6)
    }

    private func latencyColor(_ ms: Double?) -> Color {
        guard let ms else { return .secondary }
        if ms < 30 { return Color(hex: "38EF7D") }
        if ms < 100 { return Color(hex: "F2C94C") }
        return Color(hex: "FC466B")
    }

    private func latencyQuality(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        if ms < 30 { return "Excellent" }
        if ms < 100 { return "Good" }
        return "High"
    }

    // MARK: - Unprotected prompt

    /// Shown when no profile is installed: a nudge to pick one, jumping straight
    /// to the Profiles tab.
    private var unprotectedPromptCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("You're on your network's default DNS. Pick a profile to get faster, private resolution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    selectedTab = .profiles
                } label: {
                    Text("Choose a DNS profile")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                }
            }
        }
    }

    // MARK: - Speed test summary

    /// The latest internet speed test at a glance; tap to open Speed Test.
    private var speedSummaryCard: some View {
        Button {
            selectedTab = .speedTest
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Internet speed", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let result = store.lastSpeedResult {
                            Text(result.timestamp, format: .relative(presentation: .named))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    if let result = store.lastSpeedResult {
                        HStack(spacing: 10) {
                            speedMetric("arrow.down", fmtSpeed(result.downloadMbps), "Mbps")
                            speedMetric("arrow.up", fmtSpeed(result.uploadMbps), "Mbps")
                            speedMetric("timer", "\(Int(result.pingMs.rounded()))", "ms")
                        }
                    } else {
                        Text("Run your first speed test to see download, upload and ping here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func speedMetric(_ icon: String, _ value: String, _ unit: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accentGradient)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold).monospacedDigit())
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmtSpeed(_ v: Double) -> String {
        v >= 100 ? String(Int(v.rounded())) : String(format: "%.1f", v)
    }

    // MARK: - Recent activity

    /// The last few DNS changes from the connection log; tap to open the Log.
    private var recentActivityCard: some View {
        Button {
            selectedTab = .log
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Recent activity", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(store.recentActivity) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: activityIcon(entry.action))
                                .font(.caption)
                                .foregroundStyle(activityColor(entry.action))
                                .frame(width: 18)
                            Text(entry.profileName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text(entry.timestamp, format: .relative(presentation: .named))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func activityIcon(_ action: ConnectionLogEntry.LogAction) -> String {
        switch action {
        case .applied: return "checkmark.shield.fill"
        case .removed: return "shield.slash"
        case .failed: return "exclamationmark.triangle.fill"
        case .tested: return "timer"
        }
    }

    private func activityColor(_ action: ConnectionLogEntry.LogAction) -> Color {
        switch action {
        case .applied: return Color(hex: "38EF7D")
        case .removed: return .secondary
        case .failed: return Color(hex: "FC466B")
        case .tested: return Color(hex: "F2C94C")
        }
    }

    private var statusTitle: String {
        switch store.dnsStatus {
        case .active: return "Protected"
        case .installedNotEnabled: return "Not Enabled"
        case .off: return "Unprotected"
        }
    }

    private var statusStyle: AnyShapeStyle {
        switch store.dnsStatus {
        case .active: return AnyShapeStyle(AppTheme.accentGradient)
        case .installedNotEnabled: return AnyShapeStyle(AppTheme.warningGradient)
        case .off: return AnyShapeStyle(.secondary)
        }
    }

    /// The profile is on the device but iOS is ignoring it until the user picks
    /// imjaDNS in Settings — the one thing we cannot do for them.
    private var notEnabledCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("Your DNS profile is installed but switched off, so it isn't protecting you yet. Turn it on in Settings → General → VPN & Device Management → DNS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    openDNSSettings()
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.warningGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                }
            }
        }
    }

    private func openDNSSettings() {
        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList/DNS") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Network Info

    private var networkInfoCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: network.connectionType.icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentGradient)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Network")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(network.connectionType.rawValue))
                        .font(.headline)
                }

                Spacer()

                Circle()
                    .fill(network.isConnected ? Color(hex: "38EF7D") : Color(hex: "FC466B"))
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            // Offered whenever a profile exists, not just an active one: an
            // installed-but-disabled profile is still ours to remove, and
            // gating on "active" left the user no way to get rid of it.
            if store.hasProfileInstalled {
                Button {
                    store.send(.disconnectDNS)
                } label: {
                    HStack(spacing: 8) {
                        if store.isApplying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "shield.slash")
                                .font(.body.weight(.semibold))
                        }
                        Text("Disconnect DNS")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.dangerGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                    .shadow(color: Color(hex: "FC466B").opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .disabled(store.isApplying)
            }
        }
    }
}
