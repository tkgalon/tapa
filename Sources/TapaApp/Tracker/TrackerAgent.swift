import os
import ServiceManagement

/// TapaTracker, the agent inside Tapa.app that sends Leave Behind tabs to Mist. It's registered
/// with launchd when Tapa opens, so it runs at login from then on, window or not.
@MainActor
enum TrackerAgent {
    private static let service = SMAppService.agent(plistName: "id.tapa.tracker.plist")
    private static let logger = Logger(subsystem: "id.tapa", category: "app")

    static func register() {
        do {
            try service.register()
        } catch {
            logger.error("Registering the tracker failed: \(error.localizedDescription, privacy: .public)")
        }
        logger.notice("Tracker status: \(String(describing: service.status), privacy: .public)")
    }
}
