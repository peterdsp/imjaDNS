import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dnsSetupSection
                preferencesSection
                aboutSection
                dangerZone
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Settings")
        .onAppear { store.send(.onAppear) }
        .alert("Reset All Settings?", isPresented: Binding(
            get: { store.showResetAlert },
            set: { newValue in if !newValue { store.send(.cancelReset) } }
        )) {
            Button("Reset", role: .destructive) { store.send(.confirmReset) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disconnect DNS, remove all custom profiles, and clear your connection history. This cannot be undone.")
        }
    }

    // MARK: - DNS Setup

    private var dnsSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("DNS Setup", icon: "gear")

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.connected.to.line.below.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accentGradient)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device Management")
                                .font(.subheadline.weight(.medium))
                            Text("Enable imjaDNS in system settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        store.send(.openDeviceManagement)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open VPN & Device Management")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Text("Settings → General → VPN & Device Management → DNS → Select imjaDNS")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Preferences", icon: "slider.horizontal.3")

            GlassToggle(
                "Auto-Apply DNS",
                subtitle: "Restore last used DNS on app launch",
                icon: "arrow.clockwise",
                isOn: $store.autoApplyDNS.sending(\.toggleAutoApply)
            )
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("About", icon: "info.circle")

            GlassCard {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.brandGradient)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "shield.checkered")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("imjaDNS")
                                .font(.headline)
                            Text("Version \(Bundle.main.appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(icon: "lock.shield.fill", text: "Privacy-first: No data collection")
                        infoRow(icon: "network", text: "Uses Apple's native DNS API")
                        infoRow(icon: "bolt.shield.fill", text: "Supports DoH & DoT encryption")
                        infoRow(icon: "person.fill", text: "Made by Petros Dhespollari")
                    }
                }
            }
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accentGradient)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Danger Zone", icon: "exclamationmark.triangle")

            Button {
                store.send(.showResetAlert)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Settings")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                        .strokeBorder(Color(hex: "FC466B").opacity(0.5), lineWidth: 1.5)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                }
                .foregroundStyle(Color(hex: "FC466B"))
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        "\(infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
    }
}
