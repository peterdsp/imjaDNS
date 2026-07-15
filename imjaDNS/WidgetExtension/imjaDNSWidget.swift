import WidgetKit
import SwiftUI
import AppIntents

// ⚠️ STAGED — not yet in any Xcode target. See imjaDNSControl.swift in this
// folder for the one-time Widget Extension setup. This file needs the same app
// files added to the extension's target membership, plus WidgetState.swift and
// ProfileProvider.swift. Interactive buttons require iOS 17+.

// MARK: - Timeline

struct DNSEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
    let favorites: [DNSProfile]
}

struct DNSTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DNSEntry {
        DNSEntry(date: Date(), state: .systemDefault, favorites: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DNSEntry) -> Void) {
        completion(DNSEntry(date: Date(), state: WidgetStateStore.load(), favorites: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DNSEntry>) -> Void) {
        Task {
            let favorites = await ProfileProvider.favorites()
            let entry = DNSEntry(date: Date(), state: WidgetStateStore.load(), favorites: favorites)
            // Event-driven: the app calls WidgetCenter.reloadAllTimelines() on
            // every change, so we never need a scheduled refresh (zero battery).
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

// MARK: - Widget

struct imjaDNSWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.peterdsp.imjaDNS.status", provider: DNSTimelineProvider()) { entry in
            DNSWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DNS Status")
        .description("See your active DNS and switch profiles from the Home Screen.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Views

struct DNSWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DNSEntry

    var body: some View {
        switch family {
        case .systemMedium:  MediumView(entry: entry)
        case .accessoryInline: Text("DNS: \(entry.state.profileName)")
        case .accessoryRectangular: AccessoryRectView(state: entry.state)
        default: SmallView(state: entry.state)
        }
    }
}

private struct SmallView: View {
    let state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: state.categoryIcon)
                .font(.title2)
                .foregroundStyle(gradient(state.gradient))
            Spacer()
            Text(state.isActive ? "Active" : "System Default")
                .font(.caption2).foregroundStyle(.secondary)
            Text(state.profileName)
                .font(.headline).lineLimit(2).minimumScaleFactor(0.7)
            if state.hasFreshLatency, let ms = state.latencyMs {
                Text("\(Int(ms.rounded())) ms")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MediumView: View {
    let entry: DNSEntry

    var body: some View {
        HStack(spacing: 14) {
            SmallView(state: entry.state)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick switch").font(.caption2).foregroundStyle(.secondary)
                ForEach(entry.favorites) { profile in
                    Button(intent: SwitchDNSProfileIntent(profile: ProfileEntity(profile))) {
                        HStack(spacing: 6) {
                            Image(systemName: profile.category.icon).font(.caption2)
                            Text(profile.name).font(.caption).lineLimit(1)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AccessoryRectView: View {
    let state: WidgetState

    var body: some View {
        VStack(alignment: .leading) {
            Label("DNS", systemImage: state.categoryIcon).font(.caption).bold()
            Text(state.profileName).font(.caption2)
            if state.hasFreshLatency, let ms = state.latencyMs {
                Text("\(Int(ms.rounded())) ms").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private func gradient(_ hex: [String]) -> LinearGradient {
    let colors = hex.map(Color.init(hex:))
    return LinearGradient(colors: colors.isEmpty ? [.blue] : colors,
                          startPoint: .topLeading, endPoint: .bottomTrailing)
}

private extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
