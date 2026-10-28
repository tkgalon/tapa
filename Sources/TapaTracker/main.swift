import AppKit
import os
import TapaUsage

// TapaTracker runs at login as a launch agent inside Tapa.app (ADR 0003). It sends tabs on a
// Leave Behind in force to Mist, which it serves on 127.0.0.1, and counts screen time.

let logger = Logger(subsystem: "id.tapa", category: "tracker")
logger.notice("Tracker started")

MainActor.assumeIsolated {
    let blocks = BlockWatcher()
    let tabs = TabReader()
    let rest = ScreenRest()
    let usage: UsageDatabase?
    do {
        usage = try UsageDatabase()
    } catch {
        // Mist still works without screen time.
        logger.error("Opening the usage database failed: \(String(describing: error), privacy: .public)")
        usage = nil
    }

    let mist = MistServer(blocks: blocks)
    mist.start()
    let tracker = Tracker(blocks: blocks, mist: mist, tabs: tabs, rest: rest, usage: usage)
    tracker.start()
    let recorder = usage.map { UsageRecorder(database: $0, blocks: blocks, tabs: tabs, rest: rest) }
    recorder?.start()
    let access = BrowserAccessReporter()
    access.start()
    Task { await blocks.run() }
    // Kept alive for the life of the process.
    withExtendedLifetime((blocks, mist, tracker, recorder, access)) {
        RunLoop.main.run()
    }
}
