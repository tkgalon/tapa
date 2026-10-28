import AppKit
import CoreGraphics
import os
import TapaCore
import TapaUsage

/// Counts each second the Mac is in use: the app in front, the site when it's a browser, and
/// whether an Ascent is running. Seconds while the screen is locked, asleep or left idle aren't
/// counted. The database is written once a minute.
@MainActor
final class UsageRecorder {
    /// No keyboard or pointer input for this long means nobody is at the Mac.
    private static let idleAfter: TimeInterval = 120
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private let database: UsageDatabase
    private let blocks: BlockWatcher
    private let tabs: TabReader
    private let rest: ScreenRest
    private var buffer = UsageBuffer()
    private var timer: Timer?

    init(database: UsageDatabase, blocks: BlockWatcher, tabs: TabReader, rest: ScreenRest) {
        self.database = database
        self.blocks = blocks
        self.tabs = tabs
        self.rest = rest
    }

    func start() {
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.count() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func count() {
        guard !rest.isResting, !isIdle,
              let front = NSWorkspace.shared.frontmostApplication, let app = front.bundleIdentifier
        else {
            save(buffer.flush())
            return
        }
        let domain = Browser(front)
            .flatMap { tabs.address(in: $0) }
            .flatMap { URL(string: $0)?.host() }
            .flatMap { DomainName($0)?.value }
        let isFocused = blocks.snapshot?.state == .ascent
        save(buffer.add(at: .now, app: app, domain: domain, isFocused: isFocused))
    }

    private var isIdle: Bool {
        // ~0 is kCGAnyInputEventType: the time since any key, click or pointer movement.
        guard let anyInput = CGEventType(rawValue: ~0) else { return false }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput) > Self.idleAfter
    }

    private func save(_ entries: [UsageEntry]) {
        guard !entries.isEmpty else { return }
        do {
            try database.record(entries)
        } catch {
            Self.logger.error("Saving usage failed: \(String(describing: error), privacy: .public)")
        }
    }
}
