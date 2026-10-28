import Foundation
@testable import TapaCore
import Testing

struct DaemonConfigTests {
    let reddit = DomainName("reddit.com")!
    let youtube = DomainName("youtube.com")!

    var config: DaemonConfig {
        let work = LeaveBehindList(name: "Work", domains: [youtube, reddit])
        let workTime = Ritual(
            name: "Work Time",
            days: Weekday.weekdays,
            startTime: time(9),
            endTime: time(17),
            mode: .summit,
            leaveBehindIDs: [work.id]
        )
        return DaemonConfig(leaveBehindLists: [social, video, work], rituals: [workTime])
    }

    @Test func findsEveryListHoldingADomain() {
        #expect(config.lists(containing: reddit).map(\.name) == ["Social", "Work"])
        #expect(config.lists(containing: DomainName("x.com")!).isEmpty)
    }

    @Test func findsRitualsUsingAnyOfTheLists() {
        let config = config
        let work = config.leaveBehindLists[2]
        #expect(config.rituals(using: [social.id, work.id]).map(\.name) == ["Work Time"])
        #expect(config.rituals(using: [social.id]).isEmpty)
    }

    @Test func addsADomainOnce() {
        var config = config
        config.add(DomainName("x.com")!, toList: social.id)
        config.add(reddit, toList: social.id)
        #expect(config.leaveBehindLists[0].domains.map(\.value) == ["reddit.com", "tiktok.com", "x.com"])
    }

    @Test func removesOnlyFromTheNamedLists() {
        var config = config
        config.remove(reddit, fromLists: [social.id])
        #expect(config.lists(containing: reddit).map(\.name) == ["Work"])
    }

    @Test func removesFromEveryNamedList() {
        var config = config
        let all = Set(config.lists(containing: reddit).map(\.id))
        config.remove(reddit, fromLists: all)
        #expect(config.lists(containing: reddit).isEmpty)
    }

    @Test func countsAWebsiteInSeveralListsOnce() {
        let config = config
        let work = config.leaveBehindLists[2]
        #expect(config.websiteCount(in: [social.id, work.id]) == 3)
        #expect(config.websiteCount(in: []) == 0)
    }

    @Test func savesARitualInPlaceOrAtTheEnd() {
        var config = config
        var workTime = config.rituals[0]
        workTime.name = "Deep Work"
        config.save(workTime)
        let reading = Ritual(
            name: "Reading",
            days: [.saturday],
            startTime: time(20),
            endTime: time(22),
            mode: .trail,
            leaveBehindIDs: [video.id]
        )
        config.save(reading)
        #expect(config.rituals.map(\.name) == ["Deep Work", "Reading"])
    }
}
