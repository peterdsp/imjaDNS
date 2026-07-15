import Foundation
import WatchConnectivity

/// Phone side of the Apple Watch companion. App Groups don't span iOS↔watchOS,
/// so state moves over `WCSession`: the phone publishes the current DNS state +
/// favorites to the watch, and applies profile changes the watch requests
/// (only the phone can drive `NEDNSSettingsManager`).
@MainActor
final class PhoneConnectivityManager: NSObject {
    static let shared = PhoneConnectivityManager()
    private override init() { super.init() }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Best-effort push of the current state to the watch.
    func syncStateToWatch() async {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let state = WidgetStateStore.load()
        let favorites = await ProfileProvider.favorites()
        let context: [String: Any] = [
            "isActive": state.isActive,
            "profileName": state.profileName,
            "latencyMs": state.latencyMs ?? -1,
            "favorites": favorites.map { ["id": $0.id.uuidString, "name": $0.name] }
        ]
        try? session.updateApplicationContext(context)
    }

    /// Applies a watch request. Extracted so the delegate can stay lean.
    fileprivate func handle(action: String?, profileID: String?) async {
        switch action {
        case "apply":
            if let profileID, let id = UUID(uuidString: profileID),
               let profile = await ProfileProvider.profile(for: id) {
                try? await DNSApplyService.apply(profile)
            }
        case "disable":
            try? await DNSApplyService.disable()
        default:
            break
        }
        await syncStateToWatch()
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in await PhoneConnectivityManager.shared.syncStateToWatch() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Pull Sendable values out before hopping actors, then reply immediately.
        let action = message["action"] as? String
        let profileID = message["profileID"] as? String
        replyHandler(["ok": true])
        Task { @MainActor in await PhoneConnectivityManager.shared.handle(action: action, profileID: profileID) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
