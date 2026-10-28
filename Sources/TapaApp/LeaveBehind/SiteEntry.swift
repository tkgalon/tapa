import TapaCore

/// One website in the Leave Behind table, with every list that holds it and the Rituals that use
/// those lists.
struct SiteEntry: Identifiable, Equatable {
    let domain: DomainName
    let lists: [LeaveBehindList]
    let rituals: [Ritual]

    var id: String { domain.value }
    var name: String { domain.value }

    static func entries(in config: DaemonConfig, filter: LeaveBehindFilter) -> [SiteEntry] {
        var seen = Set<DomainName>()
        let domains = config.leaveBehindLists
            .filter { list in filter.listID.map { $0 == list.id } ?? true }
            .flatMap(\.domains)
            .filter { seen.insert($0).inserted }
        return domains.map { domain in
            let lists = config.lists(containing: domain)
            return SiteEntry(domain: domain, lists: lists, rituals: config.rituals(using: Set(lists.map(\.id))))
        }
    }
}
