import SwiftUI
import Charts
import ComposableArchitecture

struct InsightsView: View {
    @Bindable var store: StoreOf<InsightsFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                windowPicker
                fastestCard
                if store.stats.isEmpty {
                    emptyState
                } else {
                    chartCard
                    leaderboard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Insights")
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Window picker

    private var windowPicker: some View {
        Picker("Window", selection: Binding(
            get: { store.window },
            set: { store.send(.setWindow($0)) }
        )) {
            ForEach(TimeWindow.allCases) { window in
                Text(window.title).tag(window)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Fastest now

    private var fastestCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Fastest right now", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "00D2FF"))
                    Spacer()
                    Button {
                        store.send(.refreshFastest)
                    } label: {
                        if store.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isRefreshing)
                }

                if let fastest = store.fastest {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fastest.profile.name).font(.title3.bold())
                        Text("\(Int(fastest.latencyMs.rounded())) ms")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Apply") { store.send(.applyFastest) }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "00D2FF"))
                    }
                } else {
                    Text("Tap refresh to probe every provider and find the fastest for your network right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Latency over time").font(.headline)

                Chart {
                    ForEach(selectedSeries) { series in
                        ForEach(series.points, id: \.date) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("ms", point.ms)
                            )
                            .foregroundStyle(by: .value("Provider", series.name))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartYAxisLabel("ms")
                .frame(height: 200)

                providerChips
            }
        }
    }

    private var selectedSeries: [LatencyAnalytics.ProviderSeries] {
        store.series.filter { store.selectedProviders.contains($0.name) }
    }

    private var providerChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.stats) { stat in
                    let selected = store.selectedProviders.contains(stat.name)
                    Button {
                        store.send(.toggleProvider(stat.name))
                    } label: {
                        Text(stat.name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected ? Color(hex: "00D2FF").opacity(0.25) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Leaderboard").font(.headline)
                ForEach(Array(store.stats.enumerated()), id: \.element.id) { index, stat in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(index == 0 ? Color(hex: "00D2FF") : .secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.name)
                                .font(.subheadline.weight(index == 0 ? .bold : .regular))
                            Text("\(stat.sampleCount) samples · best \(Int(stat.bestMs.rounded())) ms")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(stat.medianMs.rounded())) ms")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(index == 0 ? Color(hex: "00D2FF") : .primary)
                    }
                    if index < store.stats.count - 1 { Divider().opacity(0.3) }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No history yet")
                    .font(.headline)
                Text("Run a speed test to start building latency history for this window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}
