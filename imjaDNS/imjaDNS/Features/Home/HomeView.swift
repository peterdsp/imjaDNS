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
            Button("Open Settings") {
                if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList/DNS") {
                    UIApplication.shared.open(url)
                }
            }
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
                Text(store.isCustomDNSActive ? "Protected" : "Unprotected")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        store.isCustomDNSActive
                            ? AnyShapeStyle(AppTheme.accentGradient)
                            : AnyShapeStyle(.secondary)
                    )

                Text(store.currentDNS)
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
                    Text(network.connectionType.rawValue)
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
            if store.isCustomDNSActive {
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
