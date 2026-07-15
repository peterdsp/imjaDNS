import Foundation

/// Concurrent, network-aware DNS probing.
///
/// Two cellular-friendly behaviours:
/// 1. **Adaptive timeout** — cellular links have higher RTT, so a slow-but-valid
///    response shouldn't read as a failure. The timeout scales with the current
///    connection type.
/// 2. **Concurrent probing** — providers are measured in parallel instead of one
///    after another, so a full scan takes ~one provider's time rather than the
///    sum. This matters most on slow cellular data.
///
/// Probing calls `DNSLatencyTester` directly (nonisolated), so the work runs off
/// the main actor and genuinely overlaps.
enum SpeedProbe {
    /// Timeout tuned to the active network. Read on the main actor because
    /// `NetworkMonitor` is main-actor isolated; pass the result into the
    /// concurrent helpers below.
    @MainActor
    static func adaptiveTimeout() -> TimeInterval {
        switch NetworkMonitor.shared.connectionType {
        case .cellular: return 7
        case .none, .unknown: return 5
        case .wifi, .ethernet: return 4
        }
    }

    /// Probes every profile in parallel, delivering each result via `onResult`
    /// as soon as it completes (completion order, not input order).
    static func probeConcurrently(
        _ profiles: [DNSProfile],
        timeout: TimeInterval,
        onResult: @escaping @Sendable (DNSProfile, Double?) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for profile in profiles {
                group.addTask {
                    let ms = await DNSLatencyTester.measure(profile: profile, timeout: timeout)
                    await onResult(profile, ms)
                }
            }
        }
    }

    /// Probes every profile in parallel and returns the fastest responder.
    static func fastest(
        among profiles: [DNSProfile],
        timeout: TimeInterval
    ) async -> (profile: DNSProfile, latencyMs: Double)? {
        await withTaskGroup(of: (DNSProfile, Double?).self) { group in
            for profile in profiles {
                group.addTask {
                    (profile, await DNSLatencyTester.measure(profile: profile, timeout: timeout))
                }
            }
            var best: (profile: DNSProfile, latencyMs: Double)?
            for await (profile, ms) in group {
                guard let ms else { continue }
                if best == nil || ms < best!.latencyMs {
                    best = (profile, ms)
                }
            }
            return best
        }
    }
}
