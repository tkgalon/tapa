import Foundation
import TapaCore

/// The end times offered when beginning an Ascent: the next whole hours that leave at least the
/// minimum session length.
enum EndTimeChoices {
    static func after(_ now: Date, calendar: Calendar = .current, count: Int = 6) -> [Date] {
        guard let hour = calendar.dateInterval(of: .hour, for: now)?.start else { return [] }
        let candidates = (1...12).compactMap { calendar.date(byAdding: .hour, value: $0, to: hour) }
        return Array(
            candidates
                .filter { $0.timeIntervalSince(now) >= AscentStateMachine.minimumSessionLength }
                .prefix(count)
        )
    }
}
