import Foundation

public struct StartRequest: Codable, Hashable, Sendable {
    public let mode: SessionMode
    public let endAt: Date
    public let leaveBehindIDs: Set<LeaveBehindList.ID>
    public let oathTaken: Bool

    public init(mode: SessionMode, endAt: Date, leaveBehindIDs: Set<LeaveBehindList.ID>, oathTaken: Bool = false) {
        self.mode = mode
        self.endAt = endAt
        self.leaveBehindIDs = leaveBehindIDs
        self.oathTaken = oathTaken
    }
}

/// Pass `now` from the trusted clock. Methods that end sessions return them so the caller can
/// record them in the Trail Log.
public struct AscentStateMachine: Codable, Hashable, Sendable {
    public static let minimumSessionLength: TimeInterval = 15 * 60
    public static let maximumSessionLength: TimeInterval = 12 * 60 * 60
    public static let defaultRestStopLength: TimeInterval = 5 * 60
    public static let restStopLengths: ClosedRange<TimeInterval> = 60...(30 * 60)

    private var sessions: [Session] = []
    public private(set) var restStop: RestStop?
    public private(set) var descentLedger: DescentLedger
    /// Stops a Ritual ended early by End or Descent from restarting within the same occurrence.
    private var ritualOccurrencesStarted: [Ritual.ID: Date] = [:]

    public init(descentLedger: DescentLedger) {
        self.descentLedger = descentLedger
    }

    public func activeSessions(at now: Date) -> [Session] {
        sessions.filter { $0.isActive(at: now) }
    }

    public func policy(at now: Date) -> EffectivePolicy {
        EffectivePolicy(activeSessions: activeSessions(at: now))
    }

    public func state(at now: Date) -> SessionState {
        if activeSessions(at: now).isEmpty {
            return .basecamp
        }
        if let restStop, restStop.endAt > now {
            return .restStop
        }
        return .ascent
    }

    /// Ends sessions past their end time with `.summitReached`, and clears a finished Rest Stop.
    @discardableResult
    public mutating func tick(now: Date) -> [Session] {
        var reached: [Session] = []
        sessions.removeAll { session in
            guard session.endAt <= now else { return false }
            reached.append(session.ended(at: session.endAt, reason: .summitReached))
            return true
        }
        if let restStop, restStop.endAt <= now || sessions.isEmpty {
            self.restStop = nil
        }
        return reached
    }

    /// Starting a Summit Mode session clears any Rest Stop.
    public mutating func start(_ request: StartRequest, now: Date) throws(TapaError) -> Session {
        let length = request.endAt.timeIntervalSince(now)
        guard (Self.minimumSessionLength...Self.maximumSessionLength).contains(length) else {
            throw .invalidDuration
        }
        guard !request.leaveBehindIDs.isEmpty else { throw .emptyLeaveBehind }
        if request.mode == .summit, !request.oathTaken {
            throw .oathRequired
        }
        return begin(Session(
            mode: request.mode,
            leaveBehindIDs: request.leaveBehindIDs,
            startAt: now,
            endAt: request.endAt,
            source: .manual
        ))
    }

    /// Returns `nil` if the Ritual isn't due or its current occurrence already started. The Oath
    /// isn't checked because it was taken when the Ritual was saved.
    public mutating func startRitual(_ ritual: Ritual, now: Date, calendar: Calendar) -> Session? {
        guard ritual.enabled,
              let occurrence = ritual.occurrence(containing: now, calendar: calendar),
              ritualOccurrencesStarted[ritual.id] != occurrence.start
        else { return nil }
        ritualOccurrencesStarted[ritual.id] = occurrence.start
        return begin(Session(
            mode: ritual.mode,
            leaveBehindIDs: ritual.leaveBehindIDs,
            startAt: now,
            endAt: occurrence.end,
            source: .ritual(id: ritual.id)
        ))
    }

    public mutating func endTrail(sessionID: Session.ID, now: Date) throws(TapaError) -> Session {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID && $0.isActive(at: now) }) else {
            throw .sessionNotFound
        }
        guard sessions[index].mode == .trail else { throw .summitLocked }
        let ended = sessions.remove(at: index).ended(at: now, reason: .end)
        if activeSessions(at: now).isEmpty {
            restStop = nil
        }
        return ended
    }

    public mutating func requestRestStop(
        length: TimeInterval = Self.defaultRestStopLength,
        now: Date
    ) throws(TapaError) -> RestStop {
        switch policy(at: now).mode {
        case nil: throw .notInAscent
        case .summit: throw .summitLocked
        case .trail: break
        }
        guard Self.restStopLengths.contains(length) else { throw .invalidDuration }
        if let restStop, restStop.endAt > now {
            throw .alreadyInRestStop
        }
        let stop = RestStop(startAt: now, endAt: now.addingTimeInterval(length))
        restStop = stop
        return stop
    }

    /// With `.summit`, ends every active Summit Mode session and leaves Trail sessions running.
    /// With `.limit`, only spends the quota; the caller must check that the Limit is committed
    /// and used up.
    public mutating func useDescent(
        reason: String,
        scope: DescentScope,
        now: Date,
        calendar: Calendar
    ) throws(TapaError) -> [Session] {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { throw .reasonRequired }
        descentLedger.roll(to: now, calendar: calendar)
        guard descentLedger.remaining > 0 else { throw .noDescentLeft }

        var ended: [Session] = []
        if scope == .summit {
            guard activeSessions(at: now).contains(where: { $0.mode == .summit }) else { throw .noSummitActive }
            sessions.removeAll { session in
                guard session.mode == .summit, session.isActive(at: now) else { return false }
                ended.append(session.ended(at: now, reason: .descent))
                return true
            }
        }
        descentLedger.record(DescentRecord(at: now, reason: reason, scope: scope))
        return ended
    }

    private mutating func begin(_ session: Session) -> Session {
        sessions.append(session)
        if session.mode == .summit {
            restStop = nil
        }
        return session
    }
}
