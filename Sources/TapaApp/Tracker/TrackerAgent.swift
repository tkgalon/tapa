import Foundation
import os
import ServiceManagement

/// TapaTracker, the helper inside Tapa.app that sends Leave Behind tabs to Mist. Tapa loads it into
/// launchd as a classic per-user agent when it opens, so it runs at login from then on, window or
/// not. ADR 0003 explains why it isn't an SMAppService agent.
@MainActor
enum TrackerAgent {
    private static let label = "id.tapa.tracker"
    private static let logger = Logger(subsystem: "id.tapa", category: "app")

    static func install() async {
        await removeLoginItem()
        let plist = plistURL
        let contents = agentPlist()
        let current = try? Data(contentsOf: plist)
        if current == contents, isLoaded {
            // Same plist: a new tracker binary only needs the running one replaced.
            launchctl(["kickstart", "-k", domain + "/" + label])
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: plist.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: plist)
        } catch {
            logger.error("Writing the tracker's agent failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        launchctl(["bootout", domain + "/" + label])
        launchctl(["bootstrap", domain, plist.path(percentEncoded: false)])
        logger.notice("Tracker loaded from \(trackerPath, privacy: .public)")
    }

    private static var domain: String { "gui/\(getuid())" }

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/LaunchAgents/\(label).plist")
    }

    private static var trackerPath: String {
        Bundle.main.bundleURL.appending(path: "Contents/MacOS/TapaTracker").path(percentEncoded: false)
    }

    private static var isLoaded: Bool {
        launchctl(["print", domain + "/" + label]) == 0
    }

    /// Points at the tracker in this copy of Tapa, so moving the app moves the agent with it.
    private static func agentPlist() -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [trackerPath],
            "AssociatedBundleIdentifiers": ["id.tapa.app"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
        ]
        return (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
    }

    /// Earlier builds registered the tracker with SMAppService. That record breaks once the app is
    /// rebuilt, and it would hold the same label, so it's removed.
    private static func removeLoginItem() async {
        let service = SMAppService.agent(plistName: "\(label).plist")
        guard service.status != .notRegistered, service.status != .notFound else { return }
        try? await service.unregister()
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
