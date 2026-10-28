import AppKit
import os

/// Reads and replaces the address of the tab in view through Apple events. The tracker and the
/// usage recorder both ask, so a reading is kept for a moment rather than asked for twice.
@MainActor
final class TabReader {
    /// How long a reading is reused.
    private static let freshness: TimeInterval = 0.2
    /// How long to leave a browser alone after the user declines Automation for it.
    private static let deniedPause: TimeInterval = 60
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private struct Reading {
        let browser: Browser
        let at: Date
        let address: String?
    }

    private var deniedUntil: [Browser: Date] = [:]
    private var lastReading: Reading?

    /// The address of the front window's tab in view, or `nil` if it can't be read.
    func address(in browser: Browser) -> String? {
        if let lastReading, lastReading.browser == browser,
           Date.now.timeIntervalSince(lastReading.at) < Self.freshness {
            return lastReading.address
        }
        guard (deniedUntil[browser] ?? .distantPast) < .now else { return nil }
        let address = run(browser.readAddress, in: browser)
        lastReading = Reading(browser: browser, at: .now, address: address)
        return address
    }

    func replaceAddress(in browser: Browser, with address: String) {
        lastReading = nil
        _ = run(browser.replaceAddress(with: address), in: browser)
    }

    private func run(_ source: String, in browser: Browser) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return result?.stringValue }

        // -1743: the user hasn't allowed Tapa to control this browser.
        if error[NSAppleScript.errorNumber] as? Int == -1743 {
            deniedUntil[browser] = .now.addingTimeInterval(Self.deniedPause)
        }
        let message = error[NSAppleScript.errorMessage] as? String ?? ""
        Self.logger.error("\(browser.rawValue, privacy: .public): \(message, privacy: .public)")
        return nil
    }
}

/// Whether the screen is locked or asleep, when there's nothing to watch or count.
@MainActor
final class ScreenRest {
    private(set) var isResting = false

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observe(workspace, [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification], resting: true)
        observe(workspace, [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification], resting: false)
        observe(distributed, [Notification.Name("com.apple.screenIsLocked")], resting: true)
        observe(distributed, [Notification.Name("com.apple.screenIsUnlocked")], resting: false)
    }

    private func observe(_ center: NotificationCenter, _ names: [Notification.Name], resting: Bool) {
        for name in names {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.isResting = resting }
            }
        }
    }
}
