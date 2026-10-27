import Foundation
import os
import TapaDaemonKit

let logger = Logger(subsystem: "id.tapa", category: "daemon")
let arguments = Array(CommandLine.arguments.dropFirst())

// Used by the uninstaller after the daemon has stopped.
if arguments.first == "--clear-hosts" {
    do {
        try HostsFileEnforcer().enforce(blocking: [])
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Couldn't clear the hosts file: \(error)\n".utf8))
        exit(1)
    }
}

guard arguments.count == 1, let clientRequirement = arguments.first else {
    FileHandle.standardError.write(Data("usage: TapaDaemon <client code signing requirement>\n".utf8))
    exit(64)
}

let bootSessionID: String
do {
    bootSessionID = try BootSession.currentID()
} catch {
    logger.fault("Can't read the boot session ID")
    exit(1)
}

let engine = SessionEngine(
    store: JSONStateStore(),
    enforcer: HostsFileEnforcer(),
    monotonic: SystemMonotonicClock(),
    bootSessionID: bootSessionID
)
let server = DaemonXPCServer(engine: engine, clientRequirement: clientRequirement)
server.resume()

Task {
    await engine.run()
}
Task {
    await NetworkTimeVerifier(engine: engine).run()
}

logger.notice("Tapa daemon started")
dispatchMain()
