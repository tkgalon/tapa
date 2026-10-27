import Foundation
import TapaCore
@testable import TapaDaemonKit
import Testing

/// Times are in Asia/Jakarta, which has no daylight saving time. 2026-10-26 is a Monday.
struct SessionEngineTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    let social = LeaveBehindList(name: "Social", domains: [DomainName("reddit.com")!, DomainName("tiktok.com")!])
    let video = LeaveBehindList(name: "Video", domains: [DomainName("youtube.com")!])

    let monotonic = FakeMonotonicClock()
    let system: FakeSystemClock
    let enforcer = RecordingEnforcer()
    let store = InMemoryStateStore()

    init() {
        system = FakeSystemClock(Date())
        system.set(date(26, 10))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func makeEngine(bootSessionID: String = "boot-1", monotonic: FakeMonotonicClock? = nil) -> SessionEngine {
        let system = system
        return SessionEngine(
            store: store,
            enforcer: enforcer,
            monotonic: monotonic ?? self.monotonic,
            bootSessionID: bootSessionID,
            calendar: calendar,
            systemTime: { system.now() }
        )
    }

    /// Lets time pass on both clocks, as it does on a running Mac.
    func pass(_ interval: TimeInterval) {
        monotonic.advance(by: interval)
        system.advance(by: interval)
    }

    func configuredEngine(rituals: [Ritual] = []) async throws -> SessionEngine {
        let engine = makeEngine()
        try await engine.updateConfig(DaemonConfig(leaveBehindLists: [social, video], rituals: rituals))
        return engine
    }

    func summit(until endAt: Date, lists: Set<UUID>) -> StartRequest {
        StartRequest(mode: .summit, endAt: endAt, leaveBehindIDs: lists, oathTaken: true)
    }

    var socialDomains: Set<DomainName> { Set(social.domains) }

    @Test func startsAtBasecampWithNothingBlocked() async {
        let snapshot = await makeEngine().snapshot()
        #expect(snapshot.state == .basecamp)
        #expect(snapshot.descentsRemaining == 2)
        #expect(!snapshot.recoveredFromUnreadableState)
        #expect(enforcer.blocked.isEmpty)
    }

    @Test func startingASessionBlocksAndSaves() async throws {
        let engine = try await configuredEngine()
        let snapshot = try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        #expect(snapshot.state == .ascent)
        #expect(snapshot.mode == .summit)
        #expect(enforcer.blocked == socialDomains)
        #expect(store.saved?.ascent.activeSessions(at: date(26, 10)).count == 1)
    }

    @Test func unblocksWhenTheSessionReachesItsEnd() async throws {
        let engine = try await configuredEngine()
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        pass(2 * 3600)
        await engine.reconcile()

        #expect(await engine.snapshot().state == .basecamp)
        #expect(enforcer.blocked.isEmpty)
    }

    @Test func restStopUnblocksAndThenBlocksAgain() async throws {
        let engine = try await configuredEngine()
        try await engine.start(StartRequest(mode: .trail, endAt: date(26, 12), leaveBehindIDs: [social.id]))

        try await engine.requestRestStop()
        #expect(enforcer.blocked.isEmpty)

        pass(5 * 60)
        await engine.reconcile()
        #expect(enforcer.blocked == socialDomains)
    }

    @Test func dueRitualsStartOnReconcile() async throws {
        let workTime = Ritual(
            name: "Work Time",
            days: Weekday.weekdays,
            startTime: TimeOfDay(hour: 11)!,
            endTime: TimeOfDay(hour: 17)!,
            mode: .summit,
            leaveBehindIDs: [video.id]
        )
        let engine = try await configuredEngine(rituals: [workTime])
        #expect(enforcer.blocked.isEmpty)

        pass(3600)
        await engine.reconcile()

        let snapshot = await engine.snapshot()
        #expect(snapshot.mode == .summit)
        #expect(snapshot.endsAt == date(26, 17))
        #expect(enforcer.blocked == Set(video.domains))
    }

    @Test func listsInForceUnderSummitCannotShrink() async throws {
        let engine = try await configuredEngine()
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        var shrunk = social
        shrunk.domains.removeLast()
        await #expect(throws: TapaError.leaveBehindLocked) {
            try await engine.updateConfig(DaemonConfig(leaveBehindLists: [shrunk, video]))
        }
    }

    @Test func runningSummitRitualsCannotChange() async throws {
        let ritual = Ritual(
            name: "Morning",
            days: Weekday.weekdays,
            startTime: TimeOfDay(hour: 9)!,
            endTime: TimeOfDay(hour: 12)!,
            mode: .summit,
            leaveBehindIDs: [social.id]
        )
        let engine = try await configuredEngine(rituals: [ritual])
        #expect(await engine.snapshot().mode == .summit)

        var shortened = ritual
        shortened.endTime = TimeOfDay(hour: 10, minute: 30)!
        await #expect(throws: TapaError.summitLocked) {
            try await engine.updateConfig(DaemonConfig(leaveBehindLists: [social, video], rituals: [shortened]))
        }
        await #expect(throws: TapaError.summitLocked) {
            try await engine.updateConfig(DaemonConfig(leaveBehindLists: [social, video], rituals: []))
        }
    }

    @Test func movingTheSystemClockCannotEndSummitEarly() async throws {
        let engine = try await configuredEngine()
        await engine.verifyClock(networkTime: date(26, 10))
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        system.set(date(26, 13))
        await engine.reconcile()

        #expect(await engine.snapshot().state == .ascent)
        #expect(enforcer.blocked == socialDomains)
    }

    @Test func sessionsSurviveADaemonRestart() async throws {
        let engine = try await configuredEngine()
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        let restarted = makeEngine()
        pass(60)
        let snapshot = await restarted.snapshot()
        #expect(snapshot.state == .ascent)
        #expect(snapshot.endsAt == date(26, 12))
    }

    @Test func afterARebootTheClockIsALowerBoundUntilVerified() async throws {
        let engine = try await configuredEngine()
        await engine.verifyClock(networkTime: date(26, 10))
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))

        // Off for three hours with the system clock moved ahead; the daemon starts 30 s after boot.
        system.set(date(26, 13, 30))
        let rebooted = makeEngine(bootSessionID: "boot-2", monotonic: FakeMonotonicClock(secondsSinceBoot: 30))

        var snapshot = await rebooted.snapshot()
        #expect(!snapshot.isClockVerified)
        #expect(snapshot.state == .ascent)
        #expect(snapshot.endsAt == date(26, 12))

        snapshot = await rebooted.verifyClock(networkTime: date(26, 13))
        #expect(snapshot.isClockVerified)
        #expect(snapshot.state == .basecamp)
        #expect(enforcer.blocked.isEmpty)
    }

    @Test func failsOpenWhenSavedStateIsUnreadable() async {
        store.failLoading(with: TestError())
        let snapshot = await makeEngine().snapshot()

        #expect(snapshot.state == .basecamp)
        #expect(snapshot.recoveredFromUnreadableState)
        #expect(enforcer.blocked.isEmpty)
        #expect(store.saved != nil)
    }

    @Test func enforcementFailuresAreRetried() async throws {
        let engine = try await configuredEngine()
        enforcer.fail(with: TestError())
        try await engine.start(summit(until: date(26, 12), lists: [social.id]))
        #expect(enforcer.blocked.isEmpty)

        enforcer.fail(with: nil)
        await engine.reconcile()
        #expect(enforcer.blocked == socialDomains)
    }

    @Test func savesOnlyWhenStateChangesOrACheckpointIsDue() async throws {
        let engine = try await configuredEngine()
        let savesAfterSetup = store.saves

        pass(5)
        await engine.reconcile()
        #expect(store.saves == savesAfterSetup)

        pass(SessionEngine.checkpointInterval)
        await engine.reconcile()
        #expect(store.saves == savesAfterSetup + 1)
    }
}
