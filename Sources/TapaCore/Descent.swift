import Foundation

public enum DescentScope: Codable, Hashable, Sendable {
    case summit
    /// A committed Limit that has run out for the day.
    case limit(id: UUID)
}

public struct DescentRecord: Codable, Hashable, Sendable {
    public let at: Date
    public let reason: String
    public let scope: DescentScope
}

/// The weekly Descent quota, shared by Summit Mode and Limits.
public struct DescentLedger: Codable, Hashable, Sendable {
    public static let defaultQuota = 2

    public private(set) var periodStart: Date
    public private(set) var used: Int
    public let quota: Int
    public private(set) var history: [DescentRecord]

    public init(now: Date, calendar: Calendar, quota: Int = Self.defaultQuota) {
        periodStart = Self.weekStart(for: now, calendar: calendar)
        used = 0
        self.quota = quota
        history = []
    }

    public var remaining: Int { max(0, quota - used) }

    public mutating func roll(to now: Date, calendar: Calendar) {
        let start = Self.weekStart(for: now, calendar: calendar)
        if start > periodStart {
            periodStart = start
            used = 0
        }
    }

    mutating func record(_ record: DescentRecord) {
        used += 1
        history.append(record)
    }

    /// Returns Monday 00.00 of the week containing `date`, whatever the calendar's first weekday.
    public static func weekStart(for date: Date, calendar: Calendar) -> Date {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = Weekday.monday.rawValue
        return mondayFirst.dateInterval(of: .weekOfYear, for: date)?.start ?? mondayFirst.startOfDay(for: date)
    }
}
