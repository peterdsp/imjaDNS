import SwiftUI
import ComposableArchitecture

struct SpeedTestView: View {
    @Bindable var store: StoreOf<SpeedTestFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Mode", selection: Binding(
                    get: { store.mode },
                    set: { store.send(.setMode($0)) }
                )) {
                    Text("DNS").tag(SpeedTestFeature.Mode.dns)
                    Text("Internet").tag(SpeedTestFeature.Mode.internet)
                }
                .pickerStyle(.segmented)

                if store.mode == .dns {
                    testButton
                    if !store.results.isEmpty {
                        resultsSection
                    }
                    if !store.pastResults.isEmpty && store.results.isEmpty {
                        pastResultsSection
                    }
                } else {
                    internetContent
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

    // MARK: - Internet bandwidth test

    @ViewBuilder private var internetContent: some View {
        internetGauge

        HStack(spacing: 12) {
            internetMetric(fmtMbps(store.downloadMbps), "Download")
            internetMetric(fmtMbps(store.uploadMbps), "Upload")
            internetMetric(store.pingMs.map { "\(Int($0.rounded()))" } ?? "–", "Ping")
            internetMetric(store.jitterMs.map { "\(Int($0.rounded()))" } ?? "–", "Jitter")
        }

        Button {
            store.send(.startInternetTest)
        } label: {
            Text(LocalizedStringKey(internetButtonTitle))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "00D2FF"))
        .disabled(store.isRunningInternet)

        if !store.scenarios.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Real-world scenarios", icon: "square.grid.2x2.fill")
                ForEach(store.scenarios) { scenarioRow($0) }
            }
        }

        Text("Measured via Cloudflare. Guidance, not a guarantee — real performance depends on your devices and Wi-Fi. Only throwaway test data leaves your device.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var internetGauge: some View {
        let frac = min(1, max(0, log10(max(0, store.liveMbps) + 1) / 3))
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 13)
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(
                        AngularGradient(colors: [Color(hex: "38BDF8"), Color(hex: "8B5CF6"), Color(hex: "38BDF8")], center: .center),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: store.liveMbps)
                VStack(spacing: 2) {
                    Text(fmtLive(store.liveMbps))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Mbps").font(.caption).foregroundStyle(.secondary)
                    Text(LocalizedStringKey(phaseLabel))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: "00D2FF"))
                        .textCase(.uppercase)
                }
            }
            .frame(width: 220, height: 220)

            if let server = store.server {
                HStack(spacing: 5) {
                    Image(systemName: "server.rack").font(.caption2)
                    Text(server).font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func internetMetric(_ value: String, _ label: LocalizedStringKey) -> some View {
        GlassCard {
            VStack(spacing: 4) {
                Text(value).font(.title3.weight(.bold).monospacedDigit())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func scenarioRow(_ s: ScenarioResult) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: s.icon)
                    .font(.title3)
                    .foregroundStyle(ratingColor(s.rating))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(s.name)).font(.subheadline.weight(.semibold))
                    Text(LocalizedStringKey(s.detail)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(LocalizedStringKey(ratingLabel(s.rating)))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ratingColor(s.rating).opacity(0.16), in: Capsule())
                    .foregroundStyle(ratingColor(s.rating))
            }
        }
    }

    private var internetButtonTitle: String {
        if store.isRunningInternet { return "Testing…" }
        return store.internetPhase == .done ? "Test again" : "Start test"
    }

    private var phaseLabel: String {
        switch store.internetPhase {
        case .idle: return "Ready"
        case .ping: return "Ping"
        case .download: return "Download"
        case .upload: return "Upload"
        case .done: return "Done"
        }
    }

    private func fmtLive(_ v: Double) -> String {
        v >= 100 ? String(Int(v.rounded())) : String(format: "%.1f", v)
    }

    private func fmtMbps(_ v: Double?) -> String {
        guard let v else { return "–" }
        return v >= 100 ? String(Int(v.rounded())) : String(format: "%.1f", v)
    }

    private func ratingColor(_ r: SpeedRating) -> Color {
        switch r {
        case .smooth: return Color(hex: "38EF7D")
        case .tight: return Color(hex: "F2C94C")
        case .struggles: return Color(hex: "FF5858")
        }
    }

    private func ratingLabel(_ r: SpeedRating) -> String {
        switch r {
        case .smooth: return "Smooth"
        case .tight: return "Tight"
        case .struggles: return "Struggles"
        }
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
