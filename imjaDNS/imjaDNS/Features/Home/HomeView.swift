import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    @ObservedObject private var network = NetworkMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusSection
                networkInfoCard
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

            if store.isCustomDNSActive {
                HStack(spacing: 16) {
                    LatencyBadge(latencyMs: store.latencyMs)

                    if store.isTestingLatency {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Testing...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            store.send(.testLatency)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Test")
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
