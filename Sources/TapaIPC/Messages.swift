import Foundation
import TapaCore

public enum DaemonRequest: Codable, Hashable, Sendable {
    case status
    case config
    case start(StartRequest)
    case endTrail(sessionID: UUID)
    /// `nil` uses the default length.
    case requestRestStop(length: TimeInterval?)
    case useDescent(reason: String, scope: DescentScope)
    case updateConfig(DaemonConfig)
}

public enum DaemonResponse: Codable, Hashable, Sendable {
    case snapshot(SessionSnapshot)
    case config(DaemonConfig)
    case refused(TapaError)
    /// The request used a protocol version the daemon doesn't speak.
    case incompatible(daemonVersion: Int)
}

public struct RequestEnvelope: Codable, Sendable {
    public let version: Int
    public let request: DaemonRequest

    public init(request: DaemonRequest, version: Int = DaemonProtocol.version) {
        self.version = version
        self.request = request
    }
}

public struct ResponseEnvelope: Codable, Sendable {
    public let version: Int
    public let response: DaemonResponse

    public init(response: DaemonResponse, version: Int = DaemonProtocol.version) {
        self.version = version
        self.response = response
    }
}
