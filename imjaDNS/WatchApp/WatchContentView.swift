import SwiftUI

// ⚠️ STAGED — watchOS target (see README.md).

struct WatchContentView: View {
    @StateObject private var conn = WatchConnectivityManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(conn.isActive ? "Active" : "System Default")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(conn.profileName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if let ms = conn.latencyMs {
                    Text("\(Int(ms.rounded())) ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !conn.favorites.isEmpty {
                    Divider()
                    ForEach(conn.favorites) { favorite in
                        Button(favorite.name) { conn.apply(favorite.id) }
                            .buttonStyle(.bordered)
                    }
                }

                if conn.isActive {
                    Button("Turn Off", role: .destructive) { conn.disable() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("imjaDNS")
        .onAppear { conn.start() }
    }
}
