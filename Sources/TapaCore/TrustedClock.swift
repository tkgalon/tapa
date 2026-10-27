import Foundation

/// Seconds since boot, including sleep. On macOS use `mach_continuous_time`, not
/// `mach_absolute_time`, which pauses during sleep.
public protocol MonotonicClock: Sendable {
    func seconds() -> TimeInterval
}

/// A wall clock that system clock changes can't move: the last trusted time plus the monotonic time
/// elapsed since.
///
/// After a reboot it's only a lower bound and ignores the system clock until
/// `verify(networkTime:monotonic:)`, so sessions can end late but never early.
public struct TrustedClock: Codable, Hashable, Sendable {
    public static let maximumAcceptedDrift: TimeInterval = 120

    public private(set) var bootSessionID: String
    public private(set) var isVerified: Bool
    private var anchorWall: Date
    private var anchorMonotonic: TimeInterval
    private var checkpointMonotonic: TimeInterval

    /// Creates an unverified clock for the first launch after install.
    public init(bootSessionID: String, systemTime: Date, monotonic: TimeInterval) {
        self.init(bootSessionID: bootSessionID, anchorWall: systemTime, anchorMonotonic: monotonic, isVerified: false)
    }

    private init(bootSessionID: String, anchorWall: Date, anchorMonotonic: TimeInterval, isVerified: Bool) {
        self.bootSessionID = bootSessionID
        self.anchorWall = anchorWall
        self.anchorMonotonic = anchorMonotonic
        checkpointMonotonic = anchorMonotonic
        self.isVerified = isVerified
    }

    public func now(monotonic: TimeInterval) -> Date {
        anchorWall.addingTimeInterval(monotonic - anchorMonotonic)
    }

    /// Call before persisting; the next boot starts from the last checkpoint.
    public mutating func checkpoint(monotonic: TimeInterval) {
        checkpointMonotonic = max(checkpointMonotonic, monotonic)
    }

    /// In the same boot, returns the clock unchanged. After a reboot, returns an unverified lower
    /// bound: the last checkpointed time plus the time since boot.
    public func resumed(bootSessionID: String) -> TrustedClock {
        guard bootSessionID != self.bootSessionID else { return self }
        return TrustedClock(
            bootSessionID: bootSessionID,
            anchorWall: now(monotonic: checkpointMonotonic),
            anchorMonotonic: 0,
            isVerified: false
        )
    }

    /// Network time is accepted even while Summit Mode is active.
    public mutating func verify(networkTime: Date, monotonic: TimeInterval) {
        anchor(at: networkTime, monotonic: monotonic)
        isVerified = true
    }

    /// Ignores the system time while unverified, and ignores changes larger than
    /// `maximumAcceptedDrift` while Summit Mode is active. Returns whether the clock moved.
    @discardableResult
    public mutating func observe(systemTime: Date, monotonic: TimeInterval, summitActive: Bool) -> Bool {
        guard isVerified else { return false }
        let drift = abs(systemTime.timeIntervalSince(now(monotonic: monotonic)))
        guard drift <= Self.maximumAcceptedDrift || !summitActive else { return false }
        anchor(at: systemTime, monotonic: monotonic)
        return true
    }

    private mutating func anchor(at wall: Date, monotonic: TimeInterval) {
        anchorWall = wall
        anchorMonotonic = monotonic
        checkpointMonotonic = monotonic
    }
}
