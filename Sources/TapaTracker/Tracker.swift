import AppKit
import os

/// Sends the tab in view to Mist when its site is on a Leave Behind in force. It looks only at the
/// browser in front, four times a second, and rests while the screen is locked or asleep.
@MainActor
final class Tracker {
    private static let interval: TimeInterval = 0.25
    /// How long to leave a browser alone after the user declines Automation for it.
    private static let deniedPause: TimeInterval = 60
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private let blocks: BlockWatcher
    private let mist: MistServer
    private var isResting = false
    private var deniedUntil: [Browser: Date] = [:]
    private var timer: Timer?

    init(blocks: BlockWatcher, mist: MistServer) {
        self.blocks = blocks
        self.mist = mist
    }

    func start() {
        observeRest()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.check() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func check() {
        guard !isResting, !blocks.blocked.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication, let browser = Browser(front),
              (deniedUntil[browser] ?? .distantPast) < .now,
              let address = run(browser.readAddress, in: browser),
              let host = URL(string: address)?.host(),
              let domain = blocks.domain(covering: host),
              let mistAddress = mist.address(for: domain, from: address)
        else { return }

        Self.logger.notice("Sending \(host, privacy: .public) to Mist")
        _ = run(browser.replaceAddress(with: mistAddress), in: browser)
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

    private func observeRest() {
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
