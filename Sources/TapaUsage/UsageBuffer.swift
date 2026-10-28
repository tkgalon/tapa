import Foundation

/// Seconds an app (and, in a browser, a site) was in front during one minute.
public struct UsageEntry: Hashable, Sendable {
    public let minute: Date
    public let app: String
    public let domain: String?
    public let isFocused: Bool
    public let seconds: Int

    public init(minute: Date, app: String, domain: String?, isFocused: Bool, seconds: Int) {
        self.minute = minute
        self.app = app
        self.domain = domain
        self.isFocused = isFocused
        self.seconds = seconds
    }
}

/// Collects one sample a second and hands back whole minutes, so the database is written once a
/// minute rather than every second.
public struct UsageBuffer {
    private struct Key: Hashable {
        let app: String
        let domain: String?
        let isFocused: Bool
    }

    private var minute: Date?
    private var seconds: [Key: Int] = [:]

    public init() {}

    /// Counts one second at `date`. Returns the previous minute's entries once `date` is in a new
    /// minute, and nothing otherwise.
    public mutating func add(at date: Date, app: String, domain: String?, isFocused: Bool) -> [UsageEntry] {
        let start = Self.minute(of: date)
        let finished = start == minute ? [] : flush()
        minute = start
        seconds[Key(app: app, domain: domain, isFocused: isFocused), default: 0] += 1
        return finished
    }

    /// Hands back what's been counted and starts over.
    public mutating func flush() -> [UsageEntry] {
        guard let minute else { return [] }
        let entries = seconds.map { key, count in
            UsageEntry(minute: minute, app: key.app, domain: key.domain, isFocused: key.isFocused, seconds: count)
        }
        seconds = [:]
        self.minute = nil
        return entries
    }

    private static func minute(of date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }
}
