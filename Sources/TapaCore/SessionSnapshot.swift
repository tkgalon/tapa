import Foundation

/// A read-only view of the daemon's state for the UI.
public struct SessionSnapshot: Codable, Hashable, Sendable {
    public let state: SessionState
    public let activeSessions: [Session]
    public let restStop: RestStop?
    /// The effective mode, or `nil` at Basecamp.
    public let mode: SessionMode?
    public let endsAt: Date?
    public let descentsRemaining: Int
    public let isClockVerified: Bool
    /// Set when the saved state couldn't be read and the daemon started over at Basecamp, so the UI
    /// can tell the user.
    public let recoveredFromUnreadableState: Bool

    public init(
        state: SessionState,
        activeSessions: [Session],
        restStop: RestStop?,
        mode: SessionMode?,
        endsAt: Date?,
        descentsRemaining: Int,
        isClockVerified: Bool,
        recoveredFromUnreadableState: Bool
    ) {
        self.state = state
        self.activeSessions = activeSessions
        self.restStop = restStop
        self.mode = mode
        self.endsAt = endsAt
        self.descentsRemaining = descentsRemaining
        self.isClockVerified = isClockVerified
        self.recoveredFromUnreadableState = recoveredFromUnreadableState
    }
}
