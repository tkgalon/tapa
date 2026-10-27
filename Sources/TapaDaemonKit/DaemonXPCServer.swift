import Foundation
import os
import TapaCore
import TapaIPC

/// Accepts XPC connections whose code signature meets `clientRequirement` and forwards their
/// requests to the engine.
public final class DaemonXPCServer: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private static let logger = Logger(subsystem: "id.tapa", category: "xpc")

    private let listener: NSXPCListener
    private let service: Service

    /// - Parameter clientRequirement: The code signing requirement clients must meet, or `nil` to
    ///   accept any client. Only tests should pass `nil`.
    public init(
        listener: NSXPCListener = NSXPCListener(machServiceName: DaemonProtocol.machServiceName),
        engine: SessionEngine,
        clientRequirement: String?
    ) {
        self.listener = listener
        service = Service(engine: engine)
        super.init()
        if let clientRequirement {
            listener.setConnectionCodeSigningRequirement(clientRequirement)
        }
        listener.delegate = self
    }

    public func resume() {
        listener.resume()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        Self.logger.info("Accepted connection from pid \(connection.processIdentifier)")
        connection.exportedInterface = DaemonProtocol.makeInterface()
        connection.exportedObject = service
        connection.resume()
        return true
    }

    final class Service: NSObject, TapaDaemonXPC, Sendable {
        let engine: SessionEngine

        init(engine: SessionEngine) {
            self.engine = engine
        }

        func perform(_ request: Data, reply: @escaping @Sendable (Data) -> Void) {
            Task {
                reply(await Self.handle(request, engine: engine))
            }
        }

        static func handle(_ message: Data, engine: SessionEngine) async -> Data {
            let response: DaemonResponse
            if let envelope = try? JSONDecoder().decode(RequestEnvelope.self, from: message),
               envelope.version == DaemonProtocol.version {
                response = await respond(to: envelope.request, engine: engine)
            } else {
                response = .incompatible(daemonVersion: DaemonProtocol.version)
            }
            // Encoding these value types can't fail. An empty reply makes the client report an
            // unexpected response instead of hanging.
            return (try? JSONEncoder().encode(ResponseEnvelope(response: response))) ?? Data()
        }

        private static func respond(to request: DaemonRequest, engine: SessionEngine) async -> DaemonResponse {
            do throws(TapaError) {
                switch request {
                case .status:
                    return .snapshot(await engine.snapshot())
                case .config:
                    return .config(await engine.config())
                case .start(let start):
                    return .snapshot(try await engine.start(start))
                case .endTrail(let sessionID):
                    return .snapshot(try await engine.endTrail(sessionID: sessionID))
                case .requestRestStop(let length):
                    let length = length ?? AscentStateMachine.defaultRestStopLength
                    return .snapshot(try await engine.requestRestStop(length: length))
                case .useDescent(let reason, let scope):
                    return .snapshot(try await engine.useDescent(reason: reason, scope: scope))
                case .updateConfig(let config):
                    return .snapshot(try await engine.updateConfig(config))
                }
            } catch {
                return .refused(error)
            }
        }
    }
}
