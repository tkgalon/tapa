import Foundation
@testable import TapaCore

/// Asia/Jakarta has no daylight saving time, so wall-clock arithmetic in tests stays exact.
let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    return calendar
}()

/// 2026-10-26 is a Monday.
func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

func minutes(_ count: Double) -> TimeInterval { count * 60 }

func hours(_ count: Double) -> TimeInterval { count * 3600 }

func time(_ hour: Int, _ minute: Int = 0) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
}

let social = LeaveBehindList(name: "Social", domains: [DomainName("reddit.com")!, DomainName("tiktok.com")!])
let video = LeaveBehindList(name: "Video", domains: [DomainName("youtube.com")!])

func machine(at now: Date) -> AscentStateMachine {
    AscentStateMachine(descentLedger: DescentLedger(now: now, calendar: calendar))
}

func trail(until endAt: Date, lists: Set<UUID> = [social.id]) -> StartRequest {
    StartRequest(mode: .trail, endAt: endAt, leaveBehindIDs: lists)
}

func summit(until endAt: Date, lists: Set<UUID> = [social.id]) -> StartRequest {
    StartRequest(mode: .summit, endAt: endAt, leaveBehindIDs: lists, oathTaken: true)
}
