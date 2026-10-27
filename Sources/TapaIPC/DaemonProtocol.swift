import Foundation

/// The XPC surface of the daemon. Requests and responses travel as JSON-encoded envelopes, so new
/// commands only need a new `DaemonRequest` case, and version mismatches are detected explicitly.
@objc public protocol TapaDaemonXPC {
    func perform(_ request: Data, reply: @escaping @Sendable (Data) -> Void)
}

public enum DaemonProtocol {
    public static let machServiceName = "id.tapa.daemon"
    public static let version = 1

    public static func makeInterface() -> NSXPCInterface {
        NSXPCInterface(with: TapaDaemonXPC.self)
    }
}
