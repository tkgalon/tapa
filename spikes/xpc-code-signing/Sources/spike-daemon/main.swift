import Foundation
import SpikeProtocol

final class Service: NSObject, SpikeService, Sendable {
    func ping(reply: @escaping @Sendable (String) -> Void) {
        reply("pong from euid \(geteuid())")
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate, Sendable {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        NSLog("accepted connection from pid %d", connection.processIdentifier)
        connection.exportedInterface = NSXPCInterface(with: SpikeService.self)
        connection.exportedObject = Service()
        connection.resume()
        return true
    }
}

let clientRequirement = CommandLine.arguments.dropFirst().first
let listener = NSXPCListener(machServiceName: spikeMachServiceName)
if let clientRequirement {
    listener.setConnectionCodeSigningRequirement(clientRequirement)
}
let delegate = ListenerDelegate()
listener.delegate = delegate
listener.resume()
NSLog("listening on %@, client requirement: %@", spikeMachServiceName, clientRequirement ?? "none")
dispatchMain()
