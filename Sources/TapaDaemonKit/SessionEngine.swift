import Foundation
import os
import TapaCore

/// The daemon's single owner of session state. Every request and every reconciliation tick goes
/// through this actor, so they can't race each other.
public actor SessionEngine {
    public static let reconcileInterval: Duration = .seconds(5)
    /// How often the trusted clock is saved when nothing else changed. After a reboot, sessions can
    /// end up to this much later than scheduled.
    public static let checkpointInterval: TimeInterval = 60

    private static let logger = Logger(subsystem: "id.tapa", category: "engine")

    private let store: any StateStore
    private let enforcer: any BlockEnforcer
    private let monotonic: any MonotonicClock
    private let systemTime: @Sendable () -> Date
    private let calendar: Calendar
    private let recoveredFromUnreadableState: Bool

    private var state: DaemonState
    private var lastSaved: DaemonState?
    private var lastSaveMonotonic: TimeInterval = -.infinity

    /// Loads the saved state, or starts at Basecamp if there is none or it can't be read.
    public init(
        store: any StateStore,
        enforcer: any BlockEnforcer,
        monotonic: any MonotonicClock,
        bootSessionID: String,
        calendar: Calendar = .current,
        systemTime: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.enforcer = enforcer
        self.monotonic = monotonic
        self.systemTime = systemTime
        self.calendar = calendar

        var loaded: DaemonState?
        var recovered = false
        do {
            loaded = try store.load()
        } catch {
            let reason = String(describing: error)
            Self.logger.error("Saved state unreadable, starting at Basecamp: \(reason, privacy: .public)")
            recovered = true
        }
        recoveredFromUnreadableState = recovered

        if var loaded {
            loaded.clock = loaded.clock.resumed(bootSessionID: bootSessionID)
            state = loaded
        } else {
            let now = systemTime()
            state = DaemonState(
                ascent: AscentStateMachine(descentLedger: DescentLedger(now: now, calendar: calendar)),
                clock: TrustedClock(bootSessionID: bootSessionID, systemTime: now, monotonic: monotonic.seconds())
            )
        }
    }

    /// Reconciles every `reconcileInterval` until the task is cancelled.
    public func run() async {
        while !Task.isCancelled {
            reconcile()
            try? await Task.sleep(for: Self.reconcileInterval)
        }
    }

    /// Ends finished sessions, starts due Rituals, and brings blocking back in line with the rules,
    /// repairing any manual edits.
    public func reconcile() {
        apply(now: advance())
    }

    public func snapshot() -> SessionSnapshot {
        let now = advance()
        apply(now: now)
        return snapshot(at: now)
    }

    public func config() -> DaemonConfig {
        state.config
    }

    @discardableResult
    public func start(_ request: StartRequest) throws(TapaError) -> SessionSnapshot {
        let now = advance()
        _ = try state.ascent.start(request, now: now)
        return commit(now: now)
    }

    @discardableResult
    public func endTrail(sessionID: Session.ID) throws(TapaError) -> SessionSnapshot {
        let now = advance()
        _ = try state.ascent.endTrail(sessionID: sessionID, now: now)
        return commit(now: now)
    }

    @discardableResult
    public func requestRestStop(
        length: TimeInterval = AscentStateMachine.defaultRestStopLength
    ) throws(TapaError) -> SessionSnapshot {
        let now = advance()
        _ = try state.ascent.requestRestStop(length: length, now: now)
        return commit(now: now)
    }

    @discardableResult
    public func useDescent(reason: String, scope: DescentScope) throws(TapaError) -> SessionSnapshot {
        let now = advance()
        _ = try state.ascent.useDescent(reason: reason, scope: scope, now: now, calendar: calendar)
        return commit(now: now)
    }

    /// Replaces the Leave Behind lists and Rituals.
    ///
    /// - Throws: `TapaError.leaveBehindLocked` if a list in force under Summit Mode would shrink,
    ///   `.summitLocked` if a running Summit Mode Ritual would change or disappear, or a Ritual's
    ///   validation error.
    @discardableResult
    public func updateConfig(_ config: DaemonConfig) throws(TapaError) -> SessionSnapshot {
        let now = advance()
        for ritual in config.rituals {
            try ritual.validate()
        }
        try LeaveBehindGuard.validate(
            old: state.config.leaveBehindLists,
            new: config.leaveBehindLists,
            locked: state.ascent.policy(at: now).lockedLeaveBehindIDs
        )
        try validateRunningSummitRituals(unchangedIn: config.rituals, now: now)

        state.config = config
        startDueRituals(now: now)
        return commit(now: now)
    }

    @discardableResult
    public func verifyClock(networkTime: Date) -> SessionSnapshot {
        state.clock.verify(networkTime: networkTime, monotonic: monotonic.seconds())
        return commit(now: advance())
    }

    private func advance() -> Date {
        let reading = monotonic.seconds()
        let summitActive = state.ascent.policy(at: state.clock.now(monotonic: reading)).mode == .summit
        state.clock.observe(systemTime: systemTime(), monotonic: reading, summitActive: summitActive)

        let now = state.clock.now(monotonic: reading)
        state.ascent.tick(now: now)
        startDueRituals(now: now)
        return now
    }

    private func startDueRituals(now: Date) {
        for ritual in state.config.rituals {
            _ = state.ascent.startRitual(ritual, now: now, calendar: calendar)
        }
    }

    private func validateRunningSummitRituals(unchangedIn rituals: [Ritual], now: Date) throws(TapaError) {
        let running = state.ascent.activeSessions(at: now).compactMap { session -> Ritual.ID? in
            guard session.mode == .summit, case .ritual(let id) = session.source else { return nil }
            return id
        }
        for id in running {
            let current = state.config.rituals.first { $0.id == id }
            let proposed = rituals.first { $0.id == id }
            guard current == proposed else { throw .summitLocked }
        }
    }

    private func commit(now: Date) -> SessionSnapshot {
        apply(now: now, forceSave: true)
        return snapshot(at: now)
    }

    private func apply(now: Date, forceSave: Bool = false) {
        let blocked: Set<DomainName> = state.ascent.state(at: now) == .ascent
            ? state.ascent.policy(at: now).blockedDomains(in: state.config.leaveBehindLists)
            : []
        do {
            if try enforcer.enforce(blocking: blocked) {
                Self.logger.notice("Blocking updated: \(blocked.count) domains")
            }
        } catch {
            let reason = String(describing: error)
            Self.logger.error("Enforcement failed, retrying next tick: \(reason, privacy: .public)")
        }
        persist(force: forceSave)
    }

    private func persist(force: Bool) {
        let reading = monotonic.seconds()
        let checkpointDue = reading - lastSaveMonotonic >= Self.checkpointInterval
        guard force || state != lastSaved || checkpointDue else { return }

        state.clock.checkpoint(monotonic: reading)
        do {
            try store.save(state)
            lastSaved = state
            lastSaveMonotonic = reading
        } catch {
            Self.logger.error("Saving state failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func snapshot(at now: Date) -> SessionSnapshot {
        var ledger = state.ascent.descentLedger
        ledger.roll(to: now, calendar: calendar)
        let policy = state.ascent.policy(at: now)
        return SessionSnapshot(
            state: state.ascent.state(at: now),
            activeSessions: state.ascent.activeSessions(at: now),
            restStop: state.ascent.restStop,
            mode: policy.mode,
            endsAt: policy.endsAt,
            descentsRemaining: ledger.remaining,
            isClockVerified: state.clock.isVerified,
            recoveredFromUnreadableState: recoveredFromUnreadableState
        )
    }
}
