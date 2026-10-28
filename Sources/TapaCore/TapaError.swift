public enum TapaError: String, Error, Codable, Sendable {
    /// A session isn't 15 minutes to 12 hours long, or a Rest Stop isn't 1 to 30 minutes long.
    case invalidDuration
    /// A Ritual has no days, or its window is shorter than 15 minutes or longer than 12 hours.
    case invalidSchedule
    case emptyLeaveBehind
    case oathRequired
    /// The request would end or loosen Summit Mode, which only a Descent can do.
    case summitLocked
    case notInAscent
    case alreadyInRestStop
    case notInRestStop
    /// The Rest Stop is still waiting, or was never asked for.
    case restStopNotReady
    case sessionNotFound
    case reasonRequired
    case noDescentLeft
    case noSummitActive
    /// The change removes a domain or app from a list that Summit Mode is enforcing.
    case leaveBehindLocked
}
