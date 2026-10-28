import AppKit
import os
import TapaUsage

/// Sends the tab in view to Mist when its site is on a Leave Behind in force. It looks only at the
/// browser in front, four times a second, and rests while the screen is locked or asleep.
@MainActor
final class Tracker {
    private static let interval: TimeInterval = 0.25
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private let blocks: BlockWatcher
    private let mist: MistServer
    private let tabs: TabReader
    private let rest: ScreenRest
    private let usage: UsageDatabase?
    private var timer: Timer?

    init(blocks: BlockWatcher, mist: MistServer, tabs: TabReader, rest: ScreenRest, usage: UsageDatabase?) {
        self.blocks = blocks
        self.mist = mist
        self.tabs = tabs
        self.rest = rest
        self.usage = usage
    }

    func start() {
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.check() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func check() {
        guard !rest.isResting, !blocks.blocked.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication, let browser = Browser(front),
              let address = tabs.address(in: browser),
              let host = URL(string: address)?.host(),
              let domain = blocks.domain(covering: host),
              let mistAddress = mist.address(for: domain, from: address)
        else { return }

        Self.logger.notice("Sending \(host, privacy: .public) to Mist")
        tabs.replaceAddress(in: browser, with: mistAddress)
        try? usage?.recordAttempt(on: domain.value, at: .now)
    }
}
