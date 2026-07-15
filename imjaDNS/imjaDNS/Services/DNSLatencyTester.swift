import Foundation
import Network

/// Measures real DNS resolution latency by issuing an actual DNS query and
/// timing the round trip.
///
/// The previous implementation opened an HTTP connection to the resolver's IP on
/// port 80. Public resolvers don't serve HTTP there, so the connection was
/// refused almost instantly and the "latency" collapsed to ~0 ms for every
/// provider. This tester sends a genuine DNS `A` query and measures the time
/// until a valid DNS response comes back, which is what a DNS speed test should
/// report.
enum DNSLatencyTester {
    /// Domain we resolve when probing a server. Using a stable, widely-cached
    /// name keeps the measurement dominated by network RTT rather than the
    /// resolver's upstream lookup cost.
    private static let probeDomain = "apple.com"

    /// Measures latency for a whole profile using the transport it actually
    /// uses (DoH over HTTPS, DoT over TLS/853, or plain UDP/53), returning the
    /// best sample across its servers. Returns `nil` if every server fails.
    static func measure(profile: DNSProfile, samples: Int = 3, timeout: TimeInterval = 4) async -> Double? {
        switch profile.protocolType {
        case .doh:
            if let urlString = profile.dohURL, let url = URL(string: urlString) {
                if let doh = await measureDoH(url: url, samples: samples, timeout: timeout) {
                    return doh
                }
            }
            // Fall back to plain UDP against the resolver IPs if DoH is blocked.
            return await measurePlain(servers: profile.servers, samples: samples, timeout: timeout)

        case .dot:
            if let best = await measureDoT(
                servers: profile.servers,
                hostname: profile.dotHostname,
                samples: samples,
                timeout: timeout
            ) {
                return best
            }
            return await measurePlain(servers: profile.servers, samples: samples, timeout: timeout)

        case .plain:
            return await measurePlain(servers: profile.servers, samples: samples, timeout: timeout)
        }
    }

    // MARK: - Plain DNS (UDP / port 53)

    private static func measurePlain(servers: [String], samples: Int, timeout: TimeInterval) async -> Double? {
        var best: Double?
        for server in servers where DNSValidation.isValidDNSServer(server) {
            let rtt = await bestSample(samples: samples) {
                await measureUDP(server: server, timeout: timeout)
            }
            if let rtt {
                best = min(best ?? rtt, rtt)
            }
        }
        return best
    }

    // MARK: - DoH (HTTPS)

    private static func measureDoH(url: URL, samples: Int, timeout: TimeInterval) async -> Double? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var best: Double?
        for _ in 0..<max(1, samples) {
            // RFC 8484 recommends a query ID of 0 for DoH.
            let query = buildQuery(domain: probeDomain, id: 0)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
            request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
            request.httpBody = query

            let start = DispatchTime.now()
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      isValidDNSResponse(data) else { continue }
                let rtt = elapsedMs(since: start)
                best = min(best ?? rtt, rtt)
            } catch {
                continue
            }
        }
        return best
    }

    // MARK: - DoT (TLS / port 853)

    private static func measureDoT(
        servers: [String],
        hostname: String?,
        samples: Int,
        timeout: TimeInterval
    ) async -> Double? {
        var best: Double?
        for server in servers where DNSValidation.isValidDNSServer(server) {
            for _ in 0..<max(1, samples) {
                if let rtt = await measureTCPTLS(
                    server: server,
                    hostname: hostname,
                    useTLS: true,
                    timeout: timeout
                ) {
                    best = min(best ?? rtt, rtt)
                }
            }
        }
        return best
    }

    // MARK: - Sampling helper

    private static func bestSample(samples: Int, _ probe: () async -> Double?) async -> Double? {
        var best: Double?
        for _ in 0..<max(1, samples) {
            if let rtt = await probe() {
                best = min(best ?? rtt, rtt)
            }
        }
        return best
    }

    // MARK: - UDP transport

    private static func measureUDP(server: String, timeout: TimeInterval) async -> Double? {
        let query = buildQuery(domain: probeDomain, id: UInt16.random(in: 0...UInt16.max))
        return await withConnection(
            server: server,
            port: 53,
            parameters: .udp,
            timeout: timeout
        ) { connection, finish in
            let start = DispatchTime.now()
            connection.send(content: query, completion: .contentProcessed { error in
                if error != nil { finish(nil); return }
                connection.receiveMessage { data, _, _, recvError in
                    if recvError != nil || data == nil || !isValidDNSResponse(data!) {
                        finish(nil)
                    } else {
                        finish(elapsedMs(since: start))
                    }
                }
            })
        }
    }

    // MARK: - TCP / TLS transport (DoT)

    private static func measureTCPTLS(
        server: String,
        hostname: String?,
        useTLS: Bool,
        timeout: TimeInterval
    ) async -> Double? {
        let query = buildQuery(domain: probeDomain, id: UInt16.random(in: 0...UInt16.max))
        // DNS over TCP/TLS prefixes the message with a 2-byte length.
        var framed = Data()
        framed.append(UInt8((query.count >> 8) & 0xFF))
        framed.append(UInt8(query.count & 0xFF))
        framed.append(query)

        let parameters: NWParameters
        if useTLS {
            let tls = NWProtocolTLS.Options()
            if let hostname {
                sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, hostname)
            }
            parameters = NWParameters(tls: tls)
        } else {
            parameters = .tcp
        }

        return await withConnection(
            server: server,
            port: 853,
            parameters: parameters,
            timeout: timeout
        ) { connection, finish in
            let start = DispatchTime.now()
            connection.send(content: framed, completion: .contentProcessed { error in
                if error != nil { finish(nil); return }
                // Read the 2-byte length prefix, then the message body.
                connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { lengthData, _, _, lenError in
                    guard lenError == nil, let lengthData, lengthData.count == 2 else {
                        finish(nil); return
                    }
                    let expected = Int(lengthData[0]) << 8 | Int(lengthData[1])
                    guard expected > 0 else { finish(nil); return }
                    connection.receive(minimumIncompleteLength: expected, maximumLength: expected) { body, _, _, bodyError in
                        if bodyError == nil, let body, isValidDNSResponse(body) {
                            finish(elapsedMs(since: start))
                        } else {
                            finish(nil)
                        }
                    }
                }
            })
        }
    }

    // MARK: - Connection plumbing

    /// Opens an `NWConnection`, runs `work` once it reaches `.ready`, and
    /// guarantees the returned continuation resolves exactly once (on success,
    /// failure, or timeout) while always tearing the connection down.
    private static func withConnection(
        server: String,
        port: UInt16,
        parameters: NWParameters,
        timeout: TimeInterval,
        work: @escaping (NWConnection, @escaping (Double?) -> Void) -> Void
    ) async -> Double? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        let host = NWEndpoint.Host(server)
        let connection = NWConnection(host: host, port: nwPort, using: parameters)
        let box = ResultBox()

        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let finish: (Double?) -> Void = { value in
                guard box.resolve() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            let timeoutItem = DispatchWorkItem { finish(nil) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    work(connection) { value in
                        timeoutItem.cancel()
                        finish(value)
                    }
                case .failed, .cancelled:
                    timeoutItem.cancel()
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    /// Thread-safe one-shot guard so a continuation never resumes twice.
    private final class ResultBox {
        private let lock = NSLock()
        private var resolved = false
        func resolve() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resolved { return false }
            resolved = true
            return true
        }
    }

    // MARK: - DNS wire format

    /// Builds a standard recursive `A`-record query for `domain`.
    private static func buildQuery(domain: String, id: UInt16) -> Data {
        var data = Data()
        // Header
        data.append(UInt8((id >> 8) & 0xFF))
        data.append(UInt8(id & 0xFF))
        data.append(0x01) // QR=0, Opcode=0, RD=1
        data.append(0x00)
        data.append(0x00); data.append(0x01) // QDCOUNT = 1
        data.append(0x00); data.append(0x00) // ANCOUNT
        data.append(0x00); data.append(0x00) // NSCOUNT
        data.append(0x00); data.append(0x00) // ARCOUNT
        // Question: QNAME
        for label in domain.split(separator: ".") {
            let bytes = Array(label.utf8)
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
        data.append(0x00) // root label
        data.append(0x00); data.append(0x01) // QTYPE = A
        data.append(0x00); data.append(0x01) // QCLASS = IN
        return data
    }

    /// Minimal sanity check: a DNS response has the QR bit set and at least a
    /// full 12-byte header.
    private static func isValidDNSResponse(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let flagsHigh = data[data.startIndex + 2]
        return (flagsHigh & 0x80) != 0 // QR = 1 (response)
    }

    private static func elapsedMs(since start: DispatchTime) -> Double {
        let ns = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return Double(ns) / 1_000_000.0
    }
}
