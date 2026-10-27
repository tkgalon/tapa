/// Applies a set of blocked domains to the system.
///
/// Implementations must be idempotent: the reconciliation loop calls `enforce(blocking:)` repeatedly
/// with the same set and expects no change when the system already matches.
public protocol BlockEnforcer: Sendable {
    /// Makes the system block exactly `domains`. An empty set removes all blocking.
    ///
    /// - Returns: Whether anything had to change.
    @discardableResult
    func enforce(blocking domains: Set<DomainName>) throws -> Bool
}
