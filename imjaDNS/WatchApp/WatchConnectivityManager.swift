import Foundation
import WatchConnectivity

// ⚠️ STAGED — part of a watchOS target that doesn't exist yet. See README.md
// in this folder. Self-contained: no shared app files required.

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    private override init() { super.init() }

    struct WatchFavorite: Identifiable, Equatable {
        let id: String
        let name: String
    }

    @Published var isActive = false
    @Published var profileName = "System Default"
    @Published var latencyMs: Double?
    @Published var favorites: [WatchFavorite] = []

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func apply(_ id: String) { send(["action": "apply", "profileID": id]) }
    func disable() { send(["action": "disable"]) }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    fileprivate func apply(context: [String: Any]) {
        isActive = context["isActive"] as? Bool ?? false
        profileName = context["profileName"] as? String ?? "System Default"
        let ms = context["latencyMs"] as? Double ?? -1
        latencyMs = ms >= 0 ? ms : nil
        if let favs = context["favorites"] as? [[String: String]] {
            favorites = favs.compactMap { dict in
                guard let id = dict["id"], let name = dict["name"] else { return nil }
                return WatchFavorite(id: id, name: name)
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let context = applicationContext
        Task { @MainActor in WatchConnectivityManager.shared.apply(context: context) }
    }
}
