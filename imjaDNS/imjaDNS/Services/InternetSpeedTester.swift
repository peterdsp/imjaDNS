import Foundation

/// Client-side internet bandwidth test using Cloudflare's public speed
/// endpoints (speed.cloudflare.com) — the same source the website uses. No
/// backend, only throwaway test bytes leave the device. Concurrent streams,
/// data-capped so it doesn't burn mobile data.
enum InternetSpeedTester {
    private static let downBase = "https://speed.cloudflare.com/__down?bytes="
    private static let upURL = "https://speed.cloudflare.com/__up"

    /// Accumulates transferred bytes and computes throughput over a post-warmup
    /// window, safe for concurrent streams.
    actor Counter {
        private let start = Date()
        private var windowStart: Date?
        private var windowBytes = 0
        private var total = 0

        func add(_ n: Int) -> Double {
            total += n
            let now = Date()
            if let ws = windowStart {
                windowBytes += n
                let dt = now.timeIntervalSince(ws)
                return dt > 0 ? Double(windowBytes) * 8 / dt / 1_000_000 : 0
            }
            if now.timeIntervalSince(start) > 0.7 { windowStart = now }
            let dt = now.timeIntervalSince(start)
            return dt > 0 ? Double(total) * 8 / dt / 1_000_000 : 0
        }

        var byteTotal: Int { total }

        func finalMbps() -> Double {
            let now = Date()
            if let ws = windowStart, now.timeIntervalSince(ws) > 0 {
                return Double(windowBytes) * 8 / now.timeIntervalSince(ws) / 1_000_000
            }
            let dt = now.timeIntervalSince(start)
            return dt > 0 ? Double(total) * 8 / dt / 1_000_000 : 0
        }
    }

    // MARK: - Ping / jitter

    static func ping(samples: Int = 16, timeout: TimeInterval = 8) async -> (ping: Double, jitter: Double) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var lat: [Double] = []
        for i in 0..<samples {
            guard let url = URL(string: downBase + "0") else { continue }
            let t0 = Date()
            do { _ = try await session.data(from: url) } catch { continue }
            let dt = Date().timeIntervalSince(t0) * 1000
            if i >= 3 { lat.append(dt) } // discard warmup
        }
        guard !lat.isEmpty else { return (0, 0) }
        lat.sort()
        let use = Array(lat.prefix(max(1, lat.count - 2))) // drop worst 2
        let ping = use[use.count / 2]
        var jit = 0.0
        for k in 1..<max(1, use.count) { jit += abs(use[k] - use[k - 1]) }
        let jitter = use.count > 1 ? jit / Double(use.count - 1) : 0
        return (ping, jitter)
    }

    // MARK: - Download

    static func download(timeout: TimeInterval = 15, onProgress: @escaping @Sendable (Double) -> Void) async -> Double {
        let cap = 120_000_000, streams = 4, chunk = 12_000_000
        let counter = Counter()
        let deadline = Date().addingTimeInterval(10)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    while Date() < deadline {
                        if await counter.byteTotal >= cap { break }
                        guard let url = URL(string: downBase + String(chunk)) else { break }
                        do {
                            let (data, _) = try await session.data(from: url)
                            let mbps = await counter.add(data.count)
                            onProgress(mbps)
                        } catch { break }
                    }
                }
            }
        }
        return await counter.finalMbps()
    }

    // MARK: - Upload

    static func upload(timeout: TimeInterval = 15, onProgress: @escaping @Sendable (Double) -> Void) async -> Double {
        let cap = 50_000_000, streams = 3, chunk = 8_000_000
        let payload = Data(count: chunk)
        let counter = Counter()
        let deadline = Date().addingTimeInterval(8)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let url = URL(string: upURL) else { return 0 }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    while Date() < deadline {
                        if await counter.byteTotal >= cap { break }
                        var req = URLRequest(url: url)
                        req.httpMethod = "POST"
                        do {
                            _ = try await session.upload(for: req, from: payload)
                            let mbps = await counter.add(chunk)
                            onProgress(mbps)
                        } catch { break }
                    }
                }
            }
        }
        return await counter.finalMbps()
    }
}
