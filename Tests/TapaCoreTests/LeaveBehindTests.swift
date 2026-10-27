import Foundation
import Testing
@testable import TapaCore

struct DomainNameTests {
    @Test(arguments: [
        ("reddit.com", "reddit.com"),
        ("  Reddit.COM ", "reddit.com"),
        ("https://www.reddit.com/r/swift?x=1", "reddit.com"),
        ("*.tiktok.com", "tiktok.com"),
        ("news.ycombinator.com:443", "news.ycombinator.com"),
        ("youtube.com.", "youtube.com"),
    ])
    func normalizesWhatPeoplePaste(raw: String, expected: String) {
        #expect(DomainName(raw)?.value == expected)
    }

    @Test(arguments: ["", "localhost", "reddit..com", "-bad.com", "spa ce.com", "under_score.com"])
    func rejectsInvalidInput(raw: String) {
        #expect(DomainName(raw) == nil)
    }

    @Test func matchesSubdomainsButNotLookalikes() {
        let reddit = DomainName("reddit.com")!
        #expect(reddit.matches(host: "reddit.com"))
        #expect(reddit.matches(host: "old.reddit.com"))
        #expect(reddit.matches(host: "WWW.Reddit.com."))
        #expect(!reddit.matches(host: "notreddit.com"))
        #expect(!reddit.matches(host: "reddit.com.evil.io"))
    }

    @Test func hostsEntriesIncludeCommonSubdomains() {
        #expect(DomainName("reddit.com")!.hostsEntries == [
            "reddit.com", "www.reddit.com", "m.reddit.com", "old.reddit.com", "mobile.reddit.com",
        ])
    }

    @Test func codableRoundTripsAndValidates() throws {
        let data = try JSONEncoder().encode([DomainName("reddit.com")!])
        #expect(String(decoding: data, as: UTF8.self) == #"["reddit.com"]"#)
        #expect(try JSONDecoder().decode([DomainName].self, from: data) == [DomainName("reddit.com")!])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DomainName].self, from: Data(#"["not a domain"]"#.utf8))
        }
    }
}

struct LeaveBehindGuardTests {
    @Test func lockedListsCanGrow() throws {
        var grown = social
        grown.domains.append(DomainName("x.com")!)
        try LeaveBehindGuard.validate(old: [social], new: [grown], locked: [social.id])
    }

    @Test func lockedListsCannotShrinkOrDisappear() {
        var shrunk = social
        shrunk.domains.removeLast()
        #expect(throws: TapaError.leaveBehindLocked) {
            try LeaveBehindGuard.validate(old: [social], new: [shrunk], locked: [social.id])
        }
        #expect(throws: TapaError.leaveBehindLocked) {
            try LeaveBehindGuard.validate(old: [social, video], new: [video], locked: [social.id])
        }
    }

    @Test func unlockedListsChangeFreely() throws {
        try LeaveBehindGuard.validate(old: [social, video], new: [social], locked: [social.id])
    }
}
