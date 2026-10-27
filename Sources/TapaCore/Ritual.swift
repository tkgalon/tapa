import Foundation

/// Raw values match `Calendar.component(.weekday, from:)`.
public enum Weekday: Int, Codable, CaseIterable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
}

public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int = 0) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// A weekly schedule that starts a session automatically.
public struct Ritual: Identifiable, Codable, Hashable, Sendable {
    public static let minimumSpanMinutes = 15
    public static let maximumSpanMinutes = 12 * 60

    public let id: UUID
    public var name: String
    public var days: Set<Weekday>
    public var startTime: TimeOfDay
    /// When earlier than `startTime`, the Ritual crosses midnight and belongs to the day it starts.
    public var endTime: TimeOfDay
    public var mode: SessionMode
    public var leaveBehindIDs: Set<LeaveBehindList.ID>
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        days: Set<Weekday>,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        mode: SessionMode,
        leaveBehindIDs: Set<LeaveBehindList.ID>,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.mode = mode
        self.leaveBehindIDs = leaveBehindIDs
        self.enabled = enabled
    }

    public var crossesMidnight: Bool { endTime <= startTime }

    public var spanMinutes: Int {
        (endTime.minutesSinceMidnight - startTime.minutesSinceMidnight + 24 * 60) % (24 * 60)
    }

    public func validate() throws(TapaError) {
        guard !days.isEmpty, (Self.minimumSpanMinutes...Self.maximumSpanMinutes).contains(spanMinutes) else {
            throw .invalidSchedule
        }
        guard !leaveBehindIDs.isEmpty else { throw .emptyLeaveBehind }
    }

    /// Returns the occurrence running at `date`. The interval includes its start and excludes its end.
    public func occurrence(containing date: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        for day in [today, yesterday] {
            if let interval = occurrence(startingOn: day, calendar: calendar),
               interval.start <= date, date < interval.end {
                return interval
            }
        }
        return nil
    }

    private func occurrence(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)),
              days.contains(weekday),
              let start = calendar.date(bySettingHour: startTime.hour, minute: startTime.minute, second: 0, of: day),
              let endDay = crossesMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day,
              let end = calendar.date(bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: endDay),
              end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}
