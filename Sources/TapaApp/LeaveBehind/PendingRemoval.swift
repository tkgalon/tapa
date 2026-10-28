import TapaCore

/// A website the user asked to remove from every list, waiting for confirmation.
struct PendingRemoval: Identifiable {
    let domain: DomainName
    let lists: [LeaveBehindList]

    var id: String { domain.value }
}
