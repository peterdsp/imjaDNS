import Foundation
import NetworkExtension

/// Reads the current Wi-Fi SSID.
///
/// ⚠️ Requires TWO things to return a real value; until both are set up this
/// returns `nil`, which makes SSID-specific rules simply not match (any-Wi-Fi,
/// cellular, and schedule rules are unaffected):
///   1. The **Access Wi-Fi Information** capability
///      (entitlement `com.apple.developer.networking.wifi-info`).
///   2. **Location When In Use** authorization at runtime (iOS returns nil SSID
///      without it). Add `NSLocationWhenInUseUsageDescription` and request auth
///      before relying on SSID rules.
enum WiFiSSIDProvider {
    static func currentSSID() async -> String? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }
}
