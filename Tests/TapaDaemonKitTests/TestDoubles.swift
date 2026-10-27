import Foundation
import os
import TapaCore

final class FakeMonotonicClock: MonotonicClock {
    private let reading: OSAllocatedUnfairLock<TimeInterval>

    init(secondsSinceBoot: TimeInterval = 1000) {
        reading = OSAllocatedUnfairLock(initialState: secondsSinceBoot)
    }

    func seconds() -> TimeInterval {
        reading.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        reading.withLock { $0 += interval }
    }
}

final class FakeSystemClock: Sendable {
    private let date: OSAllocatedUnfairLock<Date>

    init(_ date: Date) {
        self.date = OSAllocatedUnfairLock(initialState: date)
    }

    func now() -> Date {
        date.withLock { $0 }
    }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }

    func advance(by interval: TimeInterval) {
        date.withLock { $0 += interval }
    }
}

final class RecordingEnforcer: BlockEnforcer {
    private struct State {
        var blocked: Set<DomainName> = []
        var failure: (any Error)?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var blocked: Set<DomainName> {
        state.withLock { $0.blocked }
    }

    func fail(with error: (any Error)?) {
        state.withLock { $0.failure = error }
    }

    func enforce(blocking domains: Set<DomainName>) throws -> Bool {
        try state.withLock { state in
            if let failure = state.failure {
                throw failure
            }
            defer { state.blocked = domains }
            return state.blocked != domains
        }
    }
}

final class InMemoryStateStore: StateStore {
    private struct State {
        var saved: DaemonState?
        var saves = 0
        var loadFailure: (any Error)?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var saved: DaemonState? {
        state.withLock { $0.saved }
    }

    var saves: Int {
        state.withLock { $0.saves }
    }

    func failLoading(with error: any Error) {
        state.withLock { $0.loadFailure = error }
    }

    func load() throws -> DaemonState? {
        try state.withLock { state in
            if let failure = state.loadFailure {
                throw failure
            }
            return state.saved
        }
    }

    func save(_ newState: DaemonState) throws {
        state.withLock { state in
            state.saved = newState
            state.saves += 1
        }
    }
}

struct TestError: Error {}
