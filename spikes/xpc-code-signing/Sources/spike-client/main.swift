import Foundation
import SpikeProtocol

let daemonRequirement = CommandLine.arguments.dropFirst().first

let connection = NSXPCConnection(machServiceName: spikeMachServiceName, options: .privileged)
connection.remoteObjectInterface = NSXPCInterface(with: SpikeService.self)
if let daemonRequirement {
    connection.setCodeSigningRequirement(daemonRequirement)
}
// XPC calls these handlers on its own queue. Without @Sendable, Swift 6 treats closures written in
// top-level code as main-actor isolated and traps when they run elsewhere.
connection.invalidationHandler = { @Sendable in
    print("connection invalidated (rejected, or daemon not found)")
    exit(2)
}
connection.resume()

let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable error in
    print("rejected: \(error.localizedDescription)")
    exit(1)
}
guard let service = proxy as? SpikeService else {
    print("unexpected proxy type")
    exit(1)
}
service.ping { reply in
    print(reply)
    exit(0)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    print("timed out after 5 s")
    exit(3)
}
dispatchMain()
