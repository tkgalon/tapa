import AppKit
import Foundation
import Network
import os

// Spike for M4: proves the tracker can run as an SMAppService agent inside a self-signed Tapa.app,
// read and replace Chrome's active tab URL through Apple events, and serve Mist on 127.0.0.1.
// The blocked domain is fixed here. The real tracker reads Leave Behind from the daemon.

let logger = Logger(subsystem: "id.tapa", category: "tracker")
let mistPort: NWEndpoint.Port = 47800
let blockedHost = "tiktok.com"
let chrome = "com.google.Chrome"

/// Runs AppleScript only while Chrome is open, since `tell application` would launch it.
func runInChrome(_ source: String) -> String? {
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: chrome).isEmpty else { return nil }
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error {
        logger.error("Apple event failed: \(error, privacy: .public)")
        return nil
    }
    return result?.stringValue
}

func checkActiveTab() {
    let script = "tell application id \"\(chrome)\" to get URL of active tab of front window"
    guard let address = runInChrome(script), let url = URL(string: address), let host = url.host() else { return }
    guard host == blockedHost || host.hasSuffix("." + blockedHost) else { return }
    let mist = "http://127.0.0.1:\(mistPort.rawValue)/mist?site=\(blockedHost)"
    logger.notice("Sending \(host, privacy: .public) to Mist")
    _ = runInChrome("tell application id \"\(chrome)\" to set URL of active tab of front window to \"\(mist)\"")
}

func startMistServer() throws -> NWListener {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: mistPort)
    let listener = try NWListener(using: parameters)
    listener.newConnectionHandler = { connection in
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
            let body = "<!doctype html><title>Mist</title><h1>Mist spike</h1><p>\(blockedHost) is left behind.</p>"
            let response = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html; charset=utf-8\r
                Content-Length: \(body.utf8.count)\r
                Connection: close\r
                \r
                \(body)
                """
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
    listener.stateUpdateHandler = { state in
        logger.notice("Mist server: \(String(describing: state), privacy: .public)")
    }
    listener.start(queue: .main)
    return listener
}

logger.notice("Tracker started, pid \(ProcessInfo.processInfo.processIdentifier)")
let listener = try startMistServer()
let timer = Timer(timeInterval: 1, repeats: true) { _ in checkActiveTab() }
RunLoop.main.add(timer, forMode: .common)
RunLoop.main.run()
