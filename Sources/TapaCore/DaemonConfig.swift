public struct DaemonConfig: Codable, Hashable, Sendable {
    public var leaveBehindLists: [LeaveBehindList]
    public var rituals: [Ritual]

    public init(leaveBehindLists: [LeaveBehindList] = [], rituals: [Ritual] = []) {
        self.leaveBehindLists = leaveBehindLists
        self.rituals = rituals
    }

    /// The lists that hold `domain`, in list order.
    public func lists(containing domain: DomainName) -> [LeaveBehindList] {
        leaveBehindLists.filter { $0.domains.contains(domain) }
    }

    /// The Rituals that use any of `listIDs`, in Ritual order.
    public func rituals(using listIDs: Set<LeaveBehindList.ID>) -> [Ritual] {
        rituals.filter { !$0.leaveBehindIDs.isDisjoint(with: listIDs) }
    }

    /// Adds `domain` to the list. Does nothing when the list already holds it or doesn't exist.
    public mutating func add(_ domain: DomainName, toList listID: LeaveBehindList.ID) {
        guard let index = leaveBehindLists.firstIndex(where: { $0.id == listID }),
              !leaveBehindLists[index].domains.contains(domain)
        else { return }
        leaveBehindLists[index].domains.append(domain)
    }

    /// Removes `domain` from each of the lists. Other lists keep it.
    public mutating func remove(_ domain: DomainName, fromLists listIDs: Set<LeaveBehindList.ID>) {
        for index in leaveBehindLists.indices where listIDs.contains(leaveBehindLists[index].id) {
            leaveBehindLists[index].domains.removeAll { $0 == domain }
        }
    }
}
