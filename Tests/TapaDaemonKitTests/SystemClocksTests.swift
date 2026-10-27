import Foundation
@testable import TapaDaemonKit
import Testing

struct SystemClocksTests {
    @Test func monotonicClockMovesForward() async throws {
        let clock = SystemMonotonicClock()
        let first = clock.seconds()
        try await Task.sleep(for: .milliseconds(20))
        let elapsed = clock.seconds() - first
        #expect(elapsed >= 0.015)
        #expect(elapsed < 5)
    }

    @Test func bootSessionIDIsStableWithinABoot() throws {
        let id = try BootSession.currentID()
        #expect(UUID(uuidString: id) != nil)
        #expect(try BootSession.currentID() == id)
    }

    @Test func parsesHTTPDates() {
        let date = NetworkTimeVerifier.parseHTTPDate("Tue, 27 Oct 2026 08:30:05 GMT")
        #expect(date == Date(timeIntervalSince1970: 1_793_089_805))
        #expect(NetworkTimeVerifier.parseHTTPDate("yesterday") == nil)
    }
}
