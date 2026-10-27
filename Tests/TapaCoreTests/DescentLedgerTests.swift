import Foundation
import Testing
@testable import TapaCore

struct DescentLedgerTests {
    @Test func weekStartsMondayMidnight() {
        // Sunday 2026-11-01 still belongs to the week of Monday 2026-10-26.
        #expect(DescentLedger.weekStart(for: date(1, 23, month: 11), calendar: calendar) == date(26, 0))
        #expect(DescentLedger.weekStart(for: date(2, 0, month: 11), calendar: calendar) == date(2, 0, month: 11))
    }

    @Test func rollResetsOnlyInANewWeek() {
        var ledger = DescentLedger(now: date(26, 10), calendar: calendar)
        ledger.record(DescentRecord(at: date(26, 10), reason: "Urgent", scope: .summit))

        ledger.roll(to: date(1, 23, month: 11), calendar: calendar)
        #expect(ledger.remaining == 1)

        ledger.roll(to: date(2, 0, month: 11), calendar: calendar)
        #expect(ledger.remaining == 2)
        #expect(ledger.history.count == 1)
    }
}
