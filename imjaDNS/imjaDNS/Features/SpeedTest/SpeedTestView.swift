import SwiftUI
import ComposableArchitecture

struct SpeedTestView: View {
    @Bindable var store: StoreOf<SpeedTestFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                testButton
                if !store.results.isEmpty {
                    resultsSection
                }
                if !store.pastResults.isEmpty && store.results.isEmpty {
                    pastResultsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Speed Test")
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Test Button

    private var testButton: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [Color(hex: "00D2FF"), Color(hex: "7B61FF"), Color(hex: "00D2FF")],
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .rotationEffect(.degrees(store.isTesting ? 360 : 0))
                            .animation(
                                store.isTesting
                                    ? .linear(duration: 2).repeatForever(autoreverses: false)
                                    : .default,
                                value: store.isTesting
                            )
                    }

                if store.isTesting {
                    VStack(spacing: 4) {
                        Text("\(store.currentTestIndex)/\(store.totalTests)")
                            .font(.title.weight(.bold).monospacedDigit())
                        Text("Testing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("Start")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .onTapGesture {
                if !store.isTesting {
                    store.send(.startTest)
                }
            }

            Text("Test latency of all DNS providers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Results", icon: "chart.bar.fill")

            let sorted = store.profiles
                .compactMap { profile -> (DNSProfile, Double)? in
                    guard let latency = store.results[profile.id] else { return nil }
                    return (profile, latency)
                }
                .sorted { $0.1 < $1.1 }

            ForEach(Array(sorted.enumerated()), id: \.offset) { index, item in
                let (profile, latency) = item
                resultRow(profile: profile, latency: latency, rank: index + 1)
            }
        }
    }

    private func resultRow(profile: DNSProfile, latency: Double, rank: Int) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Text("#\(rank)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(rank <= 3 ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(.secondary))
                    .frame(width: 36)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.categoryGradient(for: profile.category))
                        .frame(width: 36, height: 36)
                    Image(systemName: profile.category.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.subheadline.weight(.medium))
                    Text(profile.primaryServer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(latency))ms")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(latencyColor(latency))
                    latencyBar(latency)
                }
            }
        }
    }

    private func latencyBar(_ ms: Double) -> some View {
        let normalized = min(ms / 200, 1.0)
        return GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(latencyColor(ms))
                .frame(width: geo.size.width * normalized)
        }
        .frame(width: 60, height: 4)
        .background(RoundedRectangle(cornerRadius: 2).fill(.quaternary))
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 30 { return Color(hex: "38EF7D") }
        if ms < 100 { return Color(hex: "F2C94C") }
        return Color(hex: "FC466B")
    }

    // MARK: - Past Results

    private var pastResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader("History", icon: "clock.fill")
                Spacer()
                Button("Clear") {
                    store.send(.clearResults)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            let grouped = Dictionary(grouping: store.pastResults.suffix(20)) { $0.profileName }
            ForEach(grouped.keys.sorted(), id: \.self) { name in
                if let results = grouped[name],
                   let avg = results.map(\.latencyMs).average {
                    GlassCard {
                        HStack {
                            Text(name)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("avg \(Int(avg))ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
