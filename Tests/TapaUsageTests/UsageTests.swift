import Foundation
import TapaUsage
import Testing

struct UsageBufferTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func handsBackAMinuteOnlyOnceTheNextBegins() {
        var buffer = UsageBuffer()
        for second in 0..<60 {
            let app = second < 40 ? "com.google.Chrome" : "com.apple.dt.Xcode"
            #expect(buffer.add(at: start + Double(second), app: app, domain: nil, isFocused: true).isEmpty)
        }
        let minute = buffer.add(at: start + 60, app: "com.apple.dt.Xcode", domain: nil, isFocused: true)
        #expect(Set(minute.map(\.seconds)) == [40, 20])
        #expect(Set(minute.map(\.minute)) == [start])
    }

    @Test func keepsSitesAndFocusApart() {
        var buffer = UsageBuffer()
        _ = buffer.add(at: start, app: "com.google.Chrome", domain: "github.com", isFocused: true)
        _ = buffer.add(at: start + 1, app: "com.google.Chrome", domain: "github.com", isFocused: false)
        _ = buffer.add(at: start + 2, app: "com.google.Chrome", domain: "youtube.com", isFocused: false)
        #expect(buffer.flush().count == 3)
        #expect(buffer.flush().isEmpty)
    }
}

struct UsageDatabaseTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let url = FileManager.default.temporaryDirectory.appending(path: "usage-\(UUID().uuidString).sqlite")

    @Test func sumsScreenTimeAndFocusSinceADate() throws {
        let database = try UsageDatabase(url: url)
        try database.record([
            UsageEntry(minute: start, app: "a", domain: nil, isFocused: true, seconds: 40),
            UsageEntry(minute: start, app: "b", domain: "x.com", isFocused: false, seconds: 20),
            UsageEntry(minute: start - 3600, app: "a", domain: nil, isFocused: true, seconds: 60),
        ])
        // Writing the same minute again adds to it.
        try database.record([UsageEntry(minute: start, app: "a", domain: nil, isFocused: true, seconds: 5)])

        let reader = try UsageDatabase(url: url, readOnly: true)
        #expect(try reader.totals(since: start) == UsageTotals(screenTime: 65, focused: 45))
        #expect(try reader.totals(since: start - 3600) == UsageTotals(screenTime: 125, focused: 105))
    }

    @Test func countsAttemptsSinceADate() throws {
        let database = try UsageDatabase(url: url)
        try database.recordAttempt(on: "tiktok.com", at: start - 10)
        try database.recordAttempt(on: "tiktok.com", at: start + 10)
        #expect(try database.attempts(since: start) == 1)
    }

    @Test func readingAMissingFileFails() {
        #expect(throws: UsageDatabase.Failure.self) {
            try UsageDatabase(url: url, readOnly: true)
        }
    }
}
