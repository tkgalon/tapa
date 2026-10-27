/// Everything the daemon must keep across restarts.
public struct DaemonState: Codable, Hashable, Sendable {
    public var ascent: AscentStateMachine
    public var clock: TrustedClock

    public init(ascent: AscentStateMachine, clock: TrustedClock) {
        self.ascent = ascent
        self.clock = clock
    }
}

public protocol StateStore: Sendable {
    /// Returns `nil` when no state has been saved yet.
    func load() throws -> DaemonState?
    func save(_ state: DaemonState) throws
}
