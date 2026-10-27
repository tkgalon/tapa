import Foundation
@testable import TapaCore
import Testing

struct TrustedClockTests {
    func verifiedClock() -> TrustedClock {
        var clock = TrustedClock(bootSessionID: "boot-1", systemTime: date(26, 8), monotonic: 100)
        clock.verify(networkTime: date(26, 9), monotonic: 100)
        return clock
    }

    @Test func advancesWithMonotonicTime() {
        #expect(verifiedClock().now(monotonic: 100 + hours(1)) == date(26, 10))
    }

    @Test func ignoresTheSystemClockUntilVerified() {
        var clock = TrustedClock(bootSessionID: "boot-1", systemTime: date(26, 9), monotonic: 0)
        #expect(!clock.isVerified)
        let accepted = clock.observe(systemTime: date(26, 9, 1), monotonic: 0, summitActive: false)
        #expect(!accepted)
    }

    @Test func smallCorrectionsAreAlwaysTaken() {
        var clock = verifiedClock()
        let accepted = clock.observe(systemTime: date(26, 9, 2), monotonic: 100, summitActive: true)
        #expect(accepted)
        #expect(clock.now(monotonic: 100) == date(26, 9, 2))
    }

    @Test func subSecondDriftIsIgnored() {
        var clock = verifiedClock()
        let halfSecondAhead = date(26, 9).addingTimeInterval(0.5)
        let accepted = clock.observe(systemTime: halfSecondAhead, monotonic: 100, summitActive: false)
        #expect(!accepted)
        #expect(clock.now(monotonic: 100) == date(26, 9))
    }

    @Test func bigJumpsAreIgnoredDuringSummit() {
        var clock = verifiedClock()
        let forward = clock.observe(systemTime: date(26, 15), monotonic: 100, summitActive: true)
        let backward = clock.observe(systemTime: date(26, 3), monotonic: 100, summitActive: true)
        #expect(!forward)
        #expect(!backward)
        #expect(clock.now(monotonic: 100) == date(26, 9))
    }

    @Test func bigCorrectionsAreTakenOutsideSummit() {
        var clock = verifiedClock()
        let accepted = clock.observe(systemTime: date(26, 15), monotonic: 100, summitActive: false)
        #expect(accepted)
        #expect(clock.now(monotonic: 100) == date(26, 15))
    }

    @Test func daemonRestartInTheSameBootKeepsTheClock() {
        let clock = verifiedClock()
        #expect(clock.resumed(bootSessionID: "boot-1") == clock)
    }

    @Test func newBootStartsFromALowerBoundAndIgnoresTheSystemClock() {
        var clock = verifiedClock()
        clock.checkpoint(monotonic: 100 + hours(1))  // last saved at 10.00

        // Powered off, someone moved the system clock ahead, then booted; the daemon starts 30 s after boot.
        var rebooted = clock.resumed(bootSessionID: "boot-2")
        #expect(!rebooted.isVerified)
        #expect(rebooted.now(monotonic: 30) == date(26, 10).addingTimeInterval(30))
        let accepted = rebooted.observe(systemTime: date(27, 10), monotonic: 30, summitActive: false)
        #expect(!accepted)

        // Network time then reveals the Mac was off for two hours.
        rebooted.verify(networkTime: date(26, 12), monotonic: 60)
        #expect(rebooted.isVerified)
        #expect(rebooted.now(monotonic: 60) == date(26, 12))
    }

    @Test func checkpointNeverMovesBackwards() {
        var clock = verifiedClock()
        clock.checkpoint(monotonic: 100 + hours(2))
        clock.checkpoint(monotonic: 100 + hours(1))
        #expect(clock.resumed(bootSessionID: "boot-2").now(monotonic: 0) == date(26, 11))
    }
}
