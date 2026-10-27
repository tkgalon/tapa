import Foundation

public enum SessionMode: String, Codable, Sendable {
    /// Allows Rest Stops and can be ended at any time.
    case trail
    /// Runs until its end time unless a Descent is used.
    case summit
}

public enum SessionState: String, Codable, Sendable {
    case basecamp
    case ascent
    case restStop
}

public enum SessionSource: Codable, Hashable, Sendable {
    case manual
    case ritual(id: Ritual.ID)
}

public enum EndReason: String, Codable, Sendable {
    /// The session reached its end time.
    case summitReached
    case end
    case descent
}

public struct Session: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let mode: SessionMode
    public let leaveBehindIDs: Set<LeaveBehindList.ID>
    public let startAt: Date
    /// Measured on the trusted clock, so restarts, sleep and system clock changes don't move it.
    public let endAt: Date
    public let source: SessionSource
    public private(set) var endedAt: Date?
    /// `nil` while the session is running.
    public private(set) var endReason: EndReason?

    public init(
        id: UUID = UUID(),
        mode: SessionMode,
        leaveBehindIDs: Set<LeaveBehindList.ID>,
        startAt: Date,
        endAt: Date,
        source: SessionSource
    ) {
        self.id = id
        self.mode = mode
        self.leaveBehindIDs = leaveBehindIDs
        self.startAt = startAt
        self.endAt = endAt
        self.source = source
    }

    public func isActive(at now: Date) -> Bool {
        endReason == nil && endAt > now
    }

    func ended(at date: Date, reason: EndReason) -> Session {
        var copy = self
        copy.endedAt = date
        copy.endReason = reason
        return copy
    }
}

/// A pause in blocking during Trail sessions. It doesn't move any session's end time.
public struct RestStop: Codable, Hashable, Sendable {
    public let startAt: Date
    public let endAt: Date
}
