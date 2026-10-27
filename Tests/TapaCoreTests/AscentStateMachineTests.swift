import Foundation
@testable import TapaCore
import Testing

struct StartTests {
    let now = date(26, 10)

    @Test func startsAndBlocks() throws {
        var ascent = machine(at: now)
        let session = try ascent.start(trail(until: date(26, 12)), now: now)
        #expect(session.startAt == now)
        #expect(ascent.state(at: now) == .ascent)
        #expect(ascent.policy(at: now).leaveBehindIDs == [social.id])
    }

    @Test func lengthMustBeFifteenMinutesToTwelveHours() throws {
        var ascent = machine(at: now)
        #expect(throws: TapaError.invalidDuration) {
            try ascent.start(trail(until: now.addingTimeInterval(minutes(14))), now: now)
        }
        #expect(throws: TapaError.invalidDuration) {
            try ascent.start(trail(until: now.addingTimeInterval(hours(12) + 1)), now: now)
        }
        _ = try ascent.start(trail(until: now.addingTimeInterval(minutes(15))), now: now)
        _ = try ascent.start(trail(until: now.addingTimeInterval(hours(12))), now: now)
    }

    @Test func summitNeedsTheOath() {
        var ascent = machine(at: now)
        let withoutOath = StartRequest(mode: .summit, endAt: date(26, 12), leaveBehindIDs: [social.id])
        #expect(throws: TapaError.oathRequired) { try ascent.start(withoutOath, now: now) }
    }

    @Test func needsLeaveBehind() {
        var ascent = machine(at: now)
        #expect(throws: TapaError.emptyLeaveBehind) {
            try ascent.start(trail(until: date(26, 12), lists: []), now: now)
        }
    }
}

struct EndTests {
    let now = date(26, 10)

    @Test func summitReachedAtEndTime() throws {
        var ascent = machine(at: now)
        let session = try ascent.start(summit(until: date(26, 12)), now: now)

        #expect(ascent.tick(now: date(26, 11, 59)).isEmpty)
        // Ended at its end time even when the tick comes late, e.g. after the Mac slept.
        let reached = ascent.tick(now: date(26, 14))
        #expect(reached.map(\.id) == [session.id])
        #expect(reached.first?.endReason == .summitReached)
        #expect(reached.first?.endedAt == date(26, 12))
        #expect(ascent.state(at: date(26, 14)) == .basecamp)
    }

    @Test func expiredSessionIsInactiveBeforeTick() throws {
        var ascent = machine(at: now)
        _ = try ascent.start(summit(until: date(26, 12)), now: now)
        #expect(ascent.state(at: date(26, 12)) == .basecamp)
    }

    @Test func endOnlyEndsTheChosenTrail() throws {
        var ascent = machine(at: now)
        let first = try ascent.start(trail(until: date(26, 12)), now: now)
        let second = try ascent.start(trail(until: date(26, 13), lists: [video.id]), now: now)

        let ended = try ascent.endTrail(sessionID: first.id, now: date(26, 11))
        #expect(ended.endReason == .end)
        #expect(ascent.activeSessions(at: date(26, 11)).map(\.id) == [second.id])
    }

    @Test func endIsRefusedForSummit() throws {
        var ascent = machine(at: now)
        let session = try ascent.start(summit(until: date(26, 12)), now: now)
        #expect(throws: TapaError.summitLocked) { try ascent.endTrail(sessionID: session.id, now: now) }
        #expect(throws: TapaError.sessionNotFound) { try ascent.endTrail(sessionID: UUID(), now: now) }
    }
}

struct RestStopTests {
    let now = date(26, 10)

    @Test func opensForFiveMinutesWithoutMovingTheEnd() throws {
        var ascent = machine(at: now)
        let session = try ascent.start(trail(until: date(26, 12)), now: now)

        let stop = try ascent.requestRestStop(now: date(26, 11))
        #expect(stop.endAt == date(26, 11, 5))
        #expect(ascent.state(at: date(26, 11, 3)) == .restStop)
        #expect(ascent.state(at: date(26, 11, 5)) == .ascent)
        #expect(ascent.activeSessions(at: date(26, 11)).first?.endAt == session.endAt)

        ascent.tick(now: date(26, 11, 5))
        #expect(ascent.restStop == nil)
    }

    @Test func refusedUnlessEverySessionIsTrail() throws {
        var ascent = machine(at: now)
        #expect(throws: TapaError.notInAscent) { try ascent.requestRestStop(now: now) }

        _ = try ascent.start(trail(until: date(26, 12)), now: now)
        _ = try ascent.start(summit(until: date(26, 11), lists: [video.id]), now: now)
        #expect(throws: TapaError.summitLocked) { try ascent.requestRestStop(now: now) }
        // Once the Summit Mode session ends, only Trail remains.
        _ = try ascent.requestRestStop(now: date(26, 11))
    }

    @Test func refusesOverlapsAndBadLengths() throws {
        var ascent = machine(at: now)
        _ = try ascent.start(trail(until: date(26, 12)), now: now)
        #expect(throws: TapaError.invalidDuration) { try ascent.requestRestStop(length: 0, now: now) }
        _ = try ascent.requestRestStop(now: now)
        #expect(throws: TapaError.alreadyInRestStop) { try ascent.requestRestStop(now: date(26, 10, 2)) }
    }

    @Test func summitStartingMidRestStopClosesIt() throws {
        var ascent = machine(at: now)
        _ = try ascent.start(trail(until: date(26, 12)), now: now)
        _ = try ascent.requestRestStop(now: now)
        _ = try ascent.start(summit(until: date(26, 11)), now: date(26, 10, 1))
        #expect(ascent.state(at: date(26, 10, 2)) == .ascent)
    }
}

struct DescentTests {
    let now = date(26, 10)

    @Test func endsEverySummitSessionAndKeepsTrail() throws {
        var ascent = machine(at: now)
        let summitA = try ascent.start(summit(until: date(26, 12)), now: now)
        let summitB = try ascent.start(summit(until: date(26, 14), lists: [video.id]), now: now)
        let trailC = try ascent.start(trail(until: date(26, 13)), now: now)

        let ended = try ascent.useDescent(
            reason: "Family emergency", scope: .summit, now: date(26, 11), calendar: calendar
        )

        #expect(Set(ended.map(\.id)) == [summitA.id, summitB.id])
        #expect(ended.allSatisfy { $0.endReason == .descent && $0.endedAt == date(26, 11) })
        #expect(ascent.activeSessions(at: date(26, 11)).map(\.id) == [trailC.id])
        #expect(ascent.descentLedger.remaining == 1)
        #expect(ascent.descentLedger.history.first?.reason == "Family emergency")
    }

    @Test func returnsToBasecampWhenOnlySummitWasActive() throws {
        var ascent = machine(at: now)
        _ = try ascent.start(summit(until: date(26, 12)), now: now)
        _ = try ascent.useDescent(reason: "Urgent", scope: .summit, now: now, calendar: calendar)
        #expect(ascent.state(at: now) == .basecamp)
    }

    @Test func quotaIsSharedWithLimitsAndResetsMonday() throws {
        var ascent = machine(at: now)
        _ = try ascent.useDescent(
            reason: "Need YouTube for class", scope: .limit(id: UUID()), now: now, calendar: calendar
        )
        _ = try ascent.start(summit(until: date(26, 12)), now: now)
        _ = try ascent.useDescent(reason: "Urgent", scope: .summit, now: now, calendar: calendar)

        _ = try ascent.start(summit(until: date(28, 12)), now: date(28, 10))
        #expect(throws: TapaError.noDescentLeft) {
            try ascent.useDescent(reason: "Again", scope: .summit, now: date(28, 10), calendar: calendar)
        }
        // Monday 2026-11-02 00.00 starts a new week.
        _ = try ascent.start(summit(until: date(2, 12, month: 11)), now: date(2, 0, month: 11))
        _ = try ascent.useDescent(reason: "New week", scope: .summit, now: date(2, 0, month: 11), calendar: calendar)
        #expect(ascent.descentLedger.remaining == 1)
    }

    @Test func needsAReasonAndAnActiveSummit() throws {
        var ascent = machine(at: now)
        _ = try ascent.start(trail(until: date(26, 12)), now: now)
        #expect(throws: TapaError.reasonRequired) {
            try ascent.useDescent(reason: "  ", scope: .summit, now: now, calendar: calendar)
        }
        #expect(throws: TapaError.noSummitActive) {
            try ascent.useDescent(reason: "Urgent", scope: .summit, now: now, calendar: calendar)
        }
        #expect(ascent.descentLedger.remaining == 2)
    }
}

struct RitualSessionTests {
    let workTime = Ritual(
        name: "Work Time",
        days: Weekday.weekdays,
        startTime: time(9),
        endTime: time(17),
        mode: .summit,
        leaveBehindIDs: [social.id]
    )

    @Test func startsOnceAndEndsAtTheScheduledTime() throws {
        var ascent = machine(at: date(26, 9))
        let started = ascent.startRitual(workTime, now: date(26, 9, 1), calendar: calendar)
        let session = try #require(started)
        #expect(session.endAt == date(26, 17))
        #expect(session.source == .ritual(id: workTime.id))
        #expect(ascent.startRitual(workTime, now: date(26, 9, 2), calendar: calendar) == nil)
    }

    @Test func doesNotRestartAfterDescent() throws {
        var ascent = machine(at: date(26, 9))
        _ = ascent.startRitual(workTime, now: date(26, 9), calendar: calendar)
        _ = try ascent.useDescent(reason: "Urgent", scope: .summit, now: date(26, 10), calendar: calendar)
        #expect(ascent.startRitual(workTime, now: date(26, 10, 1), calendar: calendar) == nil)
        // The next day is a new occurrence.
        #expect(ascent.startRitual(workTime, now: date(27, 9), calendar: calendar) != nil)
    }

    @Test func outsideTheWindowOrDisabledDoesNothing() {
        var ascent = machine(at: date(26, 8))
        #expect(ascent.startRitual(workTime, now: date(26, 8), calendar: calendar) == nil)
        var disabled = workTime
        disabled.enabled = false
        #expect(ascent.startRitual(disabled, now: date(26, 10), calendar: calendar) == nil)
    }

    @Test func startingTrailFirstCannotDodgeASummitRitual() throws {
        var ascent = machine(at: date(26, 8))
        let early = try ascent.start(trail(until: date(26, 12), lists: [video.id]), now: date(26, 8, 50))
        _ = ascent.startRitual(workTime, now: date(26, 9), calendar: calendar)

        #expect(ascent.policy(at: date(26, 10)).mode == .summit)
        #expect(ascent.policy(at: date(26, 10)).leaveBehindIDs == [social.id, video.id])
        #expect(throws: TapaError.summitLocked) { try ascent.requestRestStop(now: date(26, 10)) }
        // Ending the early Trail is allowed; the Ritual keeps running.
        _ = try ascent.endTrail(sessionID: early.id, now: date(26, 10))
        #expect(ascent.state(at: date(26, 10)) == .ascent)
    }
}
