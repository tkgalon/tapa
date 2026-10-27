/// Everything the daemon must keep across restarts. Config lives here too, so a config change and
/// the rules checked against the running sessions are saved in one atomic write.
public struct DaemonState: Codable, Hashable, Sendable {
    public var ascent: AscentStateMachine
    public var clock: TrustedClock
    public var config: DaemonConfig

    public init(ascent: AscentStateMachine, clock: TrustedClock, config: DaemonConfig = DaemonConfig()) {
        self.ascent = ascent
        self.clock = clock
        self.config = config
    }
}

public protocol StateStore: Sendable {
    /// Returns `nil` when no state has been saved yet.
    func load() throws -> DaemonState?
    func save(_ state: DaemonState) throws
}
