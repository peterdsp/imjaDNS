import SwiftUI
import ComposableArchitecture

struct DiagnosticsView: View {
    @Bindable var store: StoreOf<DiagnosticsFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overallCard
                if let report = store.report {
                    ForEach(report.checks) { checkRow($0) }
                }
                runButton
                Text("Reachability and DNSSEC are tested with a direct UDP query to your resolver's IP. A resolver that serves only DoH/DoT on other ports may still work even if these show a warning.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Diagnostics")
        .onAppear { store.send(.onAppear) }
    }

    private var overallCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                if store.isRunning {
                    ProgressView().controlSize(.large)
                    Text("Running checks…").font(.subheadline).foregroundStyle(.secondary)
                } else if let report = store.report {
                    Image(systemName: icon(report.overall))
                        .font(.system(size: 44))
                        .foregroundStyle(color(report.overall))
                    Text(headline(report.overall)).font(.title3.bold())
                } else {
                    Image(systemName: "stethoscope").font(.system(size: 44)).foregroundStyle(.secondary)
                    Text("Ready to check your DNS").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private func checkRow(_ check: DNSDiagnostics.Check) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon(check.status))
                    .font(.title3)
                    .foregroundStyle(color(check.status))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.title).font(.subheadline.weight(.semibold))
                    Text(check.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var runButton: some View {
        Button {
            store.send(.runTapped)
        } label: {
            Label(store.report == nil ? "Run Diagnostics" : "Run Again", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "00D2FF"))
        .disabled(store.isRunning)
    }

    // MARK: - Status styling

    private func icon(_ status: DNSDiagnostics.Status) -> String {
        switch status {
        case .pass: return "checkmark.seal.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private func color(_ status: DNSDiagnostics.Status) -> Color {
        switch status {
        case .pass: return Color(hex: "38EF7D")
        case .warn: return Color(hex: "F2C94C")
        case .fail: return Color(hex: "FF5858")
        case .unknown: return .secondary
        }
    }

    private func headline(_ status: DNSDiagnostics.Status) -> String {
        switch status {
        case .pass: return "Everything looks good"
        case .warn: return "Some things to review"
        case .fail: return "A problem was found"
        case .unknown: return "Couldn't complete checks"
        }
    }
}
