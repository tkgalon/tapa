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
    /// How long the next Rest Stop would wait before it can be taken. Optional, like the next
    /// one, so a daemon from before waits existed still decodes.
    public let nextRestStopWait: TimeInterval?
    /// When the Rest Stop asked for can be taken.
    public let restStopReadyAt: Date?

    public init(
        state: SessionState,
        activeSessions: [Session],
        restStop: RestStop?,
        mode: SessionMode?,
        endsAt: Date?,
        descentsRemaining: Int,
        isClockVerified: Bool,
        recoveredFromUnreadableState: Bool,
        nextRestStopWait: TimeInterval? = nil,
        restStopReadyAt: Date? = nil
    ) {
        self.state = state
        self.activeSessions = activeSessions
        self.restStop = restStop
        self.mode = mode
        self.endsAt = endsAt
        self.descentsRemaining = descentsRemaining
        self.isClockVerified = isClockVerified
        self.recoveredFromUnreadableState = recoveredFromUnreadableState
        self.nextRestStopWait = nextRestStopWait
        self.restStopReadyAt = restStopReadyAt
    }
}
