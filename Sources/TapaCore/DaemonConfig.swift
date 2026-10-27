public struct DaemonConfig: Codable, Hashable, Sendable {
    public var leaveBehindLists: [LeaveBehindList]
    public var rituals: [Ritual]

    public init(leaveBehindLists: [LeaveBehindList] = [], rituals: [Ritual] = []) {
        self.leaveBehindLists = leaveBehindLists
        self.rituals = rituals
    }
}
