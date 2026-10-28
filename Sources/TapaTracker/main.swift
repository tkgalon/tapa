import AppKit
import os

// TapaTracker runs at login as an agent inside Tapa.app (ADR 0002). It sends tabs on a Leave
// Behind in force to Mist, which it serves on 127.0.0.1.

Logger(subsystem: "id.tapa", category: "tracker").notice("Tracker started")

MainActor.assumeIsolated {
    let blocks = BlockWatcher()
    let mist = MistServer(blocks: blocks)
    mist.start()
    let tracker = Tracker(blocks: blocks, mist: mist)
    tracker.start()
    Task { await blocks.run() }
    // Kept alive for the life of the process.
    withExtendedLifetime((blocks, mist, tracker)) {
        RunLoop.main.run()
    }
}
