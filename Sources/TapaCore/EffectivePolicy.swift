import Foundation

/// The combined rules of all active sessions, where the strictest rule wins.
public struct EffectivePolicy: Equatable, Sendable {
    public static let basecamp = EffectivePolicy(activeSessions: [])

    /// Summit Mode if any active session is Summit Mode, or `nil` when no session is active.
    public let mode: SessionMode?
    public let leaveBehindIDs: Set<LeaveBehindList.ID>
    public let endsAt: Date?

    public init(activeSessions: some Sequence<Session>) {
        var mode: SessionMode?
        var leaveBehindIDs = Set<LeaveBehindList.ID>()
        var endsAt: Date?
        for session in activeSessions {
            mode = (mode == .summit || session.mode == .summit) ? .summit : .trail
            leaveBehindIDs.formUnion(session.leaveBehindIDs)
            endsAt = max(endsAt ?? session.endAt, session.endAt)
        }
        self.mode = mode
        self.leaveBehindIDs = leaveBehindIDs
        self.endsAt = endsAt
    }

    public var isRestStopAllowed: Bool { mode == .trail }

    /// Lists that may gain entries but not lose them.
    public var lockedLeaveBehindIDs: Set<LeaveBehindList.ID> { mode == .summit ? leaveBehindIDs : [] }

    public func blockedDomains(in lists: [LeaveBehindList]) -> Set<DomainName> {
        Set(lists.filter { leaveBehindIDs.contains($0.id) }.flatMap(\.domains))
    }
}
