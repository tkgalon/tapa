import Foundation
import TapaCore

public enum DaemonClientError: Error, Equatable {
    /// The daemon isn't running, or one side rejected the other's code signature. XPC reports both
    /// the same way.
    case unreachable
    case incompatible(daemonVersion: Int)
    case unexpectedResponse
}

/// Talks to the daemon over XPC. `NSXPCConnection` is thread-safe, so the client can be shared.
public final class DaemonClient: @unchecked Sendable {
    private let connection: NSXPCConnection

    /// Connects to the installed daemon. Pass the requirement the daemon's signature must meet.
    public convenience init(daemonRequirement: String?) {
        self.init(
            connection: NSXPCConnection(machServiceName: DaemonProtocol.machServiceName, options: .privileged),
            daemonRequirement: daemonRequirement
        )
    }

    public convenience init(endpoint: NSXPCListenerEndpoint, daemonRequirement: String? = nil) {
        self.init(connection: NSXPCConnection(listenerEndpoint: endpoint), daemonRequirement: daemonRequirement)
    }

    private init(connection: NSXPCConnection, daemonRequirement: String?) {
        self.connection = connection
        connection.remoteObjectInterface = DaemonProtocol.makeInterface()
        if let daemonRequirement {
            connection.setCodeSigningRequirement(daemonRequirement)
        }
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    public func status() async throws -> SessionSnapshot {
        try snapshot(from: await send(.status))
    }

    public func config() async throws -> DaemonConfig {
        switch try await send(.config) {
        case .config(let config): return config
        case .refused(let error): throw error
        default: throw DaemonClientError.unexpectedResponse
        }
    }

    @discardableResult
    public func start(_ request: StartRequest) async throws -> SessionSnapshot {
        try snapshot(from: await send(.start(request)))
    }

    @discardableResult
    public func endTrail(sessionID: UUID) async throws -> SessionSnapshot {
        try snapshot(from: await send(.endTrail(sessionID: sessionID)))
    }

    @discardableResult
    public func requestRestStop() async throws -> SessionSnapshot {
        try snapshot(from: await send(.requestRestStop))
    }

    @discardableResult
    public func startRestStop(length: TimeInterval? = nil) async throws -> SessionSnapshot {
        try snapshot(from: await send(.startRestStop(length: length)))
    }

    @discardableResult
    public func endRestStop() async throws -> SessionSnapshot {
        try snapshot(from: await send(.endRestStop))
    }

    @discardableResult
    public func useDescent(reason: String, scope: DescentScope) async throws -> SessionSnapshot {
        try snapshot(from: await send(.useDescent(reason: reason, scope: scope)))
    }

    @discardableResult
    public func updateConfig(_ config: DaemonConfig) async throws -> SessionSnapshot {
        try snapshot(from: await send(.updateConfig(config)))
    }

    /// Throws `TapaError` when the daemon refuses the request, or `DaemonClientError`.
    public func send(_ request: DaemonRequest) async throws -> DaemonResponse {
        let message = try JSONEncoder().encode(RequestEnvelope(request: request))
        let reply: Data = try await withCheckedThrowingContinuation { continuation in
            // XPC calls exactly one of these, on its own queue.
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable _ in
                continuation.resume(throwing: DaemonClientError.unreachable)
            }
            guard let daemon = proxy as? TapaDaemonXPC else {
                continuation.resume(throwing: DaemonClientError.unexpectedResponse)
                return
            }
            daemon.perform(message) { @Sendable reply in
                continuation.resume(returning: reply)
            }
        }

        guard let envelope = try? JSONDecoder().decode(ResponseEnvelope.self, from: reply) else {
            throw DaemonClientError.unexpectedResponse
        }
        if case .incompatible(let daemonVersion) = envelope.response {
            throw DaemonClientError.incompatible(daemonVersion: daemonVersion)
        }
        return envelope.response
    }

    private func snapshot(from response: DaemonResponse) throws -> SessionSnapshot {
        switch response {
        case .snapshot(let snapshot): return snapshot
        case .refused(let error): throw error
        default: throw DaemonClientError.unexpectedResponse
        }
    }
}
