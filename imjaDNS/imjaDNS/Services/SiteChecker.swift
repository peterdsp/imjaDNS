import Foundation

/// Checks a website two ways, both through whatever DNS is currently active on
/// the device: does the name resolve (and to what, how fast), and does it
/// actually load over HTTPS. Together these tell "blocked by DNS" apart from
/// "resolves fine but unreachable".
enum SiteChecker {
    /// Resolves a hostname with the system resolver (which honours the active
    /// DNS profile) and times it. Runs the blocking `getaddrinfo` off the main
    /// actor.
    static func resolve(_ host: String, timeout: TimeInterval = 6) async -> (ip: String, ms: Double)? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo(
                    ai_flags: 0,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var info: UnsafeMutablePointer<addrinfo>?
                let start = Date()
                let status = getaddrinfo(host, "443", &hints, &info)
                let ms = Date().timeIntervalSince(start) * 1000
                defer { if info != nil { freeaddrinfo(info) } }

                guard status == 0, let first = info else {
                    continuation.resume(returning: nil)
                    return
                }

                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let named = getnameinfo(
                    first.pointee.ai_addr,
                    first.pointee.ai_addrlen,
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                guard named == 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (String(cString: buffer), ms))
            }
        }
    }

    /// Attempts to load the site over HTTPS. Any HTTP response (even 4xx/5xx)
    /// counts as reachable; a connection failure or timeout does not.
    static func reachability(_ host: String, timeout: TimeInterval = 8) async -> (reachable: Bool, status: Int?, ms: Double) {
        guard let url = URL(string: "https://\(host)") else { return (false, nil, 0) }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpShouldUsePipelining = true
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("imjaDNS", forHTTPHeaderField: "User-Agent")

        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let ms = Date().timeIntervalSince(start) * 1000
            return (true, (response as? HTTPURLResponse)?.statusCode, ms)
        } catch {
            let ms = Date().timeIntervalSince(start) * 1000
            return (false, nil, ms)
        }
    }

    /// Runs both checks and folds them into a single result.
    static func check(_ site: Website) async -> SiteCheckResult {
        async let dns = resolve(site.domain)
        async let reach = reachability(site.domain)
        let (resolved, reachable) = await (dns, reach)

        var result = SiteCheckResult()
        result.phase = .done
        result.resolvedIP = resolved?.ip
        result.dnsMs = resolved?.ms
        result.reachable = reachable.reachable
        result.httpStatus = reachable.status
        result.reachMs = reachable.ms
        result.checkedAt = Date()
        return result
    }
}
