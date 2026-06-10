import SwiftUI
import ComposableArchitecture

struct ConnectionLogView: View {
    @Bindable var store: StoreOf<ConnectionLogFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if store.entries.isEmpty {
                    emptyState
                } else {
                    logEntries
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Connection Log")
        .toolbar {
            if !store.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        store.send(.clearLog)
                    }
                    .font(.subheadline)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Activity Yet")
                .font(.title3.weight(.semibold))
            Text("DNS changes will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var logEntries: some View {
        LazyVStack(spacing: 10) {
            ForEach(store.entries) { entry in
                logEntryRow(entry)
            }
        }
    }

    private func logEntryRow(_ entry: ConnectionLogEntry) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(actionColor(entry.action))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.profileName)
                            .font(.subheadline.weight(.medium))
                        Text(entry.action.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(actionColor(entry.action))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(actionColor(entry.action).opacity(0.15)))
                    }

                    Text(entry.servers.joined(separator: ", "))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.timestamp, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(entry.timestamp, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func actionColor(_ action: ConnectionLogEntry.LogAction) -> Color {
        switch action {
        case .applied: return Color(hex: "38EF7D")
        case .removed: return Color(hex: "F2C94C")
        case .failed: return Color(hex: "FC466B")
        case .tested: return Color(hex: "00D2FF")
        }
    }
}
