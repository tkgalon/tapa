import Foundation
import Testing
@testable import TapaCore

struct EffectivePolicyTests {
    func session(_ mode: SessionMode, until endAt: Date, lists: Set<UUID>) -> Session {
        Session(mode: mode, leaveBehindIDs: lists, startAt: date(26, 9), endAt: endAt, source: .manual)
    }

    @Test func noSessionsIsBasecamp() {
        #expect(EffectivePolicy(activeSessions: []) == .basecamp)
    }

    @Test func oneSummitSessionMakesItSummit() {
        let policy = EffectivePolicy(activeSessions: [
            session(.trail, until: date(26, 12), lists: [social.id]),
            session(.summit, until: date(26, 11), lists: [video.id]),
        ])
        #expect(policy.mode == .summit)
        #expect(!policy.isRestStopAllowed)
        #expect(policy.lockedLeaveBehindIDs == [social.id, video.id])
    }

    @Test func listsAreUnitedAndLastEndWins() {
        let policy = EffectivePolicy(activeSessions: [
            session(.trail, until: date(26, 12), lists: [social.id]),
            session(.trail, until: date(26, 15), lists: [video.id]),
        ])
        #expect(policy.mode == .trail)
        #expect(policy.isRestStopAllowed)
        #expect(policy.lockedLeaveBehindIDs.isEmpty)
        #expect(policy.leaveBehindIDs == [social.id, video.id])
        #expect(policy.endsAt == date(26, 15))
        #expect(policy.blockedDomains(in: [social, video]).map(\.value).sorted()
            == ["reddit.com", "tiktok.com", "youtube.com"])
    }
}
