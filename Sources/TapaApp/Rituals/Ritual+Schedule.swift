import Foundation
import TapaCore

extension Ritual {
    /// "Weekdays, 09.00–17.00"
    func schedule(calendar: Calendar = .current) -> String {
        let times = "\(startTime.formatted(calendar: calendar))–\(endTime.formatted(calendar: calendar))"
        return "\(days.summary(calendar: calendar)), \(times)"
    }

    /// Whether running Summit Mode holds this Ritual, so it can't change until it ends.
    func isLocked(by snapshot: SessionSnapshot?) -> Bool {
        snapshot?.activeSessions.contains { $0.mode == .summit && $0.source == .ritual(id: id) } ?? false
    }

    func isRunning(in snapshot: SessionSnapshot?) -> Bool {
        snapshot?.activeSessions.contains { $0.source == .ritual(id: id) } ?? false
    }
}

extension TimeOfDay {
    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? .midnight
    }

    static let midnight = TimeOfDay(hour: 0)!

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    func formatted(calendar: Calendar = .current) -> String {
        date(calendar: calendar).formatted(.dateTime.hour().minute())
    }
}

extension Weekday {
    /// The week in the order the calendar shows it, from its first weekday.
    static func week(calendar: Calendar = .current) -> [Weekday] {
        let all = allCases
        let first = calendar.firstWeekday - 1
        return Array(all[first...] + all[..<first])
    }

    static func today(calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: .now)) ?? .monday
    }

    var next: Weekday {
        Weekday(rawValue: rawValue % 7 + 1) ?? .sunday
    }

    func shortName(calendar: Calendar = .current) -> String {
        calendar.shortWeekdaySymbols[rawValue - 1]
    }
}

extension Set<Weekday> {
    /// "Every day", "Weekdays", "Weekends", a run such as "Tue–Thu", or the days one by one.
    func summary(calendar: Calendar = .current) -> String {
        switch self {
        case Set(Weekday.allCases): return String(localized: "Every day")
        case Weekday.weekdays: return String(localized: "Weekdays")
        case [.saturday, .sunday]: return String(localized: "Weekends")
        default: break
        }
        let week = Weekday.week(calendar: calendar)
        let positions = week.indices.filter { contains(week[$0]) }
        let names = positions.map { week[$0].shortName(calendar: calendar) }
        if names.count >= 3, let first = positions.first, let last = positions.last, last - first == names.count - 1 {
            return "\(names[0])–\(names[names.count - 1])"
        }
        return names.formatted(.list(type: .and, width: .narrow))
    }
}
