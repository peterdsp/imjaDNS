import SwiftUI

// ⚠️ STAGED — @main entry for the watchOS target (see README.md).

@main
struct imjaDNSWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
        }
    }
}
