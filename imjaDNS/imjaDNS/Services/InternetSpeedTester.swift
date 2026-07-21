import Foundation

/// Client-side internet bandwidth test using Cloudflare's public speed
/// endpoints (speed.cloudflare.com) — the same source the website uses. No
/// backend, only throwaway test bytes leave the device. Concurrent streams,
/// data-capped so it doesn't burn mobile data.
enum InternetSpeedTester {
    private static let downBase = "https://speed.cloudflare.com/__down?bytes="
    private static let upURL = "https://speed.cloudflare.com/__up"
    private static let traceURL = "https://speed.cloudflare.com/cdn-cgi/trace"

    /// Cloudflare serves only some `bytes` values and answers the rest with a
    /// 1-byte 403 body: 10 MB streams fine, 12 MB is refused every time. A
    /// worker that gets refused drops to the next size here rather than
    /// treating the error body as payload.
    private static let downSizes = [10_000_000, 25_000_000, 1_000_000]

    // MARK: - Counter

    /// Accumulates transferred bytes and computes throughput over a post-warmup
    /// window. Touched from the URLSession delegate queue and from tasks.
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private let start = Date()
        private let warmup: TimeInterval
        private var windowStart: Date?
        private var windowBytes = 0
        private var total = 0

        init(warmup: TimeInterval) { self.warmup = warmup }

        @discardableResult
        func add(_ n: Int) -> Double {
            lock.lock()
            defer { lock.unlock() }
            total += n
            let now = Date()
            if windowStart == nil {
                if now.timeIntervalSince(start) > warmup { windowStart = now }
            } else {
                windowBytes += n
            }
            return mbps(at: now)
        }

        var byteTotal: Int {
            lock.lock()
            defer { lock.unlock() }
            return total
        }

        func finalMbps() -> Double {
            lock.lock()
            defer { lock.unlock() }
            return mbps(at: Date())
        }

        /// Caller holds `lock`. A window that just opened holds too little to
        /// divide by, so fall back to the whole-run average until it fills —
        /// otherwise the first bytes after warmup read as a spike, and a window
        /// that never received any read as 0.
        private func mbps(at now: Date) -> Double {
            if let windowStart, windowBytes > 0 {
                let dt = now.timeIntervalSince(windowStart)
                if dt >= 0.25 { return Double(windowBytes) * 8 / dt / 1_000_000 }
            }
            let dt = now.timeIntervalSince(start)
            return dt > 0 ? Double(total) * 8 / dt / 1_000_000 : 0
        }
    }

    // MARK: - Streaming probe

    /// Counts a transfer as it moves instead of when it finishes.
    /// `URLSession.data(from:)` and `upload(for:from:)` only hand back a
    /// completed response, so a chunk cut short by the deadline or the request
    /// timeout contributed nothing — on a link too slow to finish a chunk
    /// inside the timeout, every stream reported zero.
    private final class StreamProbe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        enum Direction { case download, upload }

        private let counter: Counter
        private let direction: Direction
        private let onProgress: @Sendable (Double) -> Void
        private let lock = NSLock()
        private var waiters: [Int: CheckedContinuation<Int, Never>] = [:]
        private var codes: [Int: Int] = [:]

        init(counter: Counter, direction: Direction, onProgress: @escaping @Sendable (Double) -> Void) {
            self.counter = counter
            self.direction = direction
            self.onProgress = onProgress
        }

        /// Runs `task` to completion and returns its HTTP status, or 0 if it was
        /// cancelled or never answered.
        func run(_ task: URLSessionTask) async -> Int {
            await withCheckedContinuation { continuation in
                lock.lock()
                waiters[task.taskIdentifier] = continuation
                lock.unlock()
                task.resume()
            }
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            lock.lock()
            codes[dataTask.taskIdentifier] = code
            lock.unlock()
            completionHandler(code == 200 ? .allow : .cancel)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard direction == .download else { return }
            onProgress(counter.add(data.count))
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didSendBodyData bytesSent: Int64,
            totalBytesSent: Int64,
            totalBytesExpectedToSend: Int64
        ) {
            guard direction == .upload else { return }
            onProgress(counter.add(Int(bytesSent)))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            lock.lock()
            let code = codes.removeValue(forKey: task.taskIdentifier) ?? 0
            let waiter = waiters.removeValue(forKey: task.taskIdentifier)
            lock.unlock()
            waiter?.resume(returning: code)
        }
    }

    /// Cancels every in-flight transfer the moment the clock or the data cap
    /// runs out — mid-chunk included, so the cap actually holds on a metered
    /// connection.
    private static func stopper(session: URLSession, counter: Counter, cap: Int, deadline: Date) -> Task<Void, Never> {
        Task {
            while Date() < deadline, counter.byteTotal < cap {
                if (try? await Task.sleep(nanoseconds: 100_000_000)) == nil { return }
            }
            session.invalidateAndCancel()
        }
    }

    // MARK: - Server

    /// Cloudflare is anycast: a request already lands on the PoP with the
    /// shortest path to the device, so there is no server to pick. This only
    /// reports which one answered, the way speedtest.net names the server it
    /// chose.
    static func server(timeout: TimeInterval = 6) async -> String? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        guard let url = URL(string: traceURL),
              let (data, _) = try? await session.data(from: url),
              let body = String(data: data, encoding: .utf8)
        else { return nil }

        var colo: String?
        var country: String?
        for line in body.split(separator: "\n") {
            let pair = line.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            if pair[0] == "colo" { colo = String(pair[1]) }
            if pair[0] == "loc" { country = String(pair[1]) }
        }
        guard let colo, !colo.isEmpty else { return nil }
        guard let country, !country.isEmpty else { return colo }
        return "\(colo) · \(country)"
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
            guard let (_, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { continue }
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

    /// A sustained-throughput download. On an unmetered link the run is
    /// governed by the clock (a ~12 s window after a 2 s TCP ramp-up) so the
    /// reading reflects steady-state speed rather than an opening burst — on a
    /// fast link the old 100 MB cap ended the test in ~1 s, which read high and
    /// noisy. On cellular the cap stays tight to protect the user's data plan,
    /// which naturally shortens the run; see [[cellular-first-quality]].
    static func download(metered: Bool, timeout: TimeInterval = 25, onProgress: @escaping @Sendable (Double) -> Void) async -> Double {
        let cap = metered ? 80_000_000 : 600_000_000
        let seconds: TimeInterval = metered ? 8 : 12
        let warmup: TimeInterval = metered ? 1.0 : 2.0
        let streams = 4
        let counter = Counter(warmup: warmup)
        let deadline = Date().addingTimeInterval(seconds)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let probe = StreamProbe(counter: counter, direction: .download, onProgress: onProgress)
        let session = URLSession(configuration: config, delegate: probe, delegateQueue: nil)
        let stop = stopper(session: session, counter: counter, cap: cap, deadline: deadline)
        defer {
            stop.cancel()
            session.invalidateAndCancel()
        }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    var size = 0
                    var errors = 0
                    while Date() < deadline, counter.byteTotal < cap, size < downSizes.count, errors < 3 {
                        guard let url = URL(string: downBase + String(downSizes[size])) else { break }
                        switch await probe.run(session.dataTask(with: url)) {
                        case 200: errors = 0
                        case 0: errors += 1 // cancelled by the stopper, or no reply
                        default: size += 1 // Cloudflare refused this size
                        }
                    }
                }
            }
        }
        return counter.finalMbps()
    }

    // MARK: - Upload

    /// The upload counterpart to `download`: clock-governed on an unmetered
    /// link for a steady-state reading, data-capped on cellular. Uploads run a
    /// touch shorter than downloads since the typical link is slower up.
    static func upload(metered: Bool, timeout: TimeInterval = 25, onProgress: @escaping @Sendable (Double) -> Void) async -> Double {
        let cap = metered ? 40_000_000 : 300_000_000
        let seconds: TimeInterval = metered ? 6 : 10
        let warmup: TimeInterval = metered ? 0.7 : 1.5
        let streams = 3, chunk = 8_000_000
        let payload = Data(count: chunk)
        let counter = Counter(warmup: warmup)
        let deadline = Date().addingTimeInterval(seconds)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        let probe = StreamProbe(counter: counter, direction: .upload, onProgress: onProgress)
        let session = URLSession(configuration: config, delegate: probe, delegateQueue: nil)
        let stop = stopper(session: session, counter: counter, cap: cap, deadline: deadline)
        defer {
            stop.cancel()
            session.invalidateAndCancel()
        }
        guard let url = URL(string: upURL) else { return 0 }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    var errors = 0
                    while Date() < deadline, counter.byteTotal < cap, errors < 3 {
                        var req = URLRequest(url: url)
                        req.httpMethod = "POST"
                        switch await probe.run(session.uploadTask(with: req, from: payload)) {
                        case 200: errors = 0
                        default: errors += 1
                        }
                    }
                }
            }
        }
        return counter.finalMbps()
    }
}
