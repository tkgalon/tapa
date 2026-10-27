import Foundation
import os

/// Verifies the trusted clock with the `Date` header of HTTPS responses.
///
/// HTTPS is used instead of NTP because TLS authenticates the server, it works on networks that
/// block NTP, and a system clock moved far ahead makes certificates look expired, which leaves the
/// clock at its safe lower bound.
public struct NetworkTimeVerifier: Sendable {
    public static let defaultSources = [
        URL(string: "https://www.apple.com")!,
        URL(string: "https://www.cloudflare.com")!,
        URL(string: "https://www.google.com")!,
    ]

    private static let logger = Logger(subsystem: "id.tapa", category: "time")

    private let engine: SessionEngine
    private let sources: [URL]
    private let retryInterval: Duration

    public init(engine: SessionEngine, sources: [URL] = Self.defaultSources, retryInterval: Duration = .seconds(60)) {
        self.engine = engine
        self.sources = sources
        self.retryInterval = retryInterval
    }

    /// Retries until the clock is verified, for example when the Mac boots offline.
    public func run() async {
        while !Task.isCancelled {
            if await engine.snapshot().isClockVerified {
                return
            }
            if let networkTime = await fetchNetworkTime() {
                await engine.verifyClock(networkTime: networkTime)
                Self.logger.notice("Clock verified with network time")
                return
            }
            try? await Task.sleep(for: retryInterval)
        }
    }

    private func fetchNetworkTime() async -> Date? {
        for source in sources {
            var request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.httpMethod = "HEAD"
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Date"),
                  let date = Self.parseHTTPDate(header)
            else { continue }
            return date
        }
        return nil
    }

    static func parseHTTPDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }
}
