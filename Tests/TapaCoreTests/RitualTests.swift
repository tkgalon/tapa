import Foundation
import Testing
@testable import TapaCore

struct RitualTests {
    let workTime = Ritual(
        name: "Work Time",
        days: Weekday.weekdays,
        startTime: time(9),
        endTime: time(17),
        mode: .summit,
        leaveBehindIDs: [social.id]
    )

    let fridayNight = Ritual(
        name: "Friday night",
        days: [.friday],
        startTime: time(22),
        endTime: time(2),
        mode: .trail,
        leaveBehindIDs: [social.id]
    )

    @Test func occurrenceOnScheduledDay() {
        #expect(workTime.occurrence(containing: date(26, 12), calendar: calendar)
            == DateInterval(start: date(26, 9), end: date(26, 17)))
    }

    @Test func occurrenceIsHalfOpen() {
        #expect(workTime.occurrence(containing: date(26, 9), calendar: calendar) != nil)
        #expect(workTime.occurrence(containing: date(26, 17), calendar: calendar) == nil)
    }

    @Test func noOccurrenceOnOtherDays() {
        // 2026-10-31 is a Saturday.
        #expect(workTime.occurrence(containing: date(31, 12), calendar: calendar) == nil)
    }

    @Test func crossingMidnightBelongsToStartDay() {
        // Friday 2026-10-30 22.00 to Saturday 02.00.
        let expected = DateInterval(start: date(30, 22), end: date(31, 2))
        #expect(fridayNight.occurrence(containing: date(30, 23), calendar: calendar) == expected)
        #expect(fridayNight.occurrence(containing: date(31, 1, 59), calendar: calendar) == expected)
        #expect(fridayNight.occurrence(containing: date(31, 23), calendar: calendar) == nil)
        // Thursday night does not run: the Ritual is Friday's.
        #expect(fridayNight.occurrence(containing: date(30, 1), calendar: calendar) == nil)
    }

    @Test func validation() throws {
        try workTime.validate()
        try fridayNight.validate()

        var tooShort = workTime
        tooShort.endTime = time(9, 10)
        #expect(throws: TapaError.invalidSchedule) { try tooShort.validate() }

        var tooLong = workTime
        tooLong.endTime = time(21, 1)
        #expect(throws: TapaError.invalidSchedule) { try tooLong.validate() }

        var empty = workTime
        empty.endTime = empty.startTime
        #expect(throws: TapaError.invalidSchedule) { try empty.validate() }

        var noDays = workTime
        noDays.days = []
        #expect(throws: TapaError.invalidSchedule) { try noDays.validate() }

        var noLists = workTime
        noLists.leaveBehindIDs = []
        #expect(throws: TapaError.emptyLeaveBehind) { try noLists.validate() }
    }
}
