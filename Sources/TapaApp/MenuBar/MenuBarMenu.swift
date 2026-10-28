import AppKit
import SwiftUI
import TapaCore

/// The status item's menu: a quick Ascent at Basecamp, the time left and the way out during one,
/// then the window and Quit.
struct MenuBarMenu: View {
    @Environment(DaemonStore.self) private var daemon
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            switch daemon.connection {
            case .connected:
                if let snapshot = daemon.snapshot, snapshot.state != .basecamp {
                    AscentMenu(snapshot: snapshot, openTapa: openTapa)
                } else {
                    BasecampMenu(openTapa: openTapa)
                }
            case .connecting:
                Text("Connecting to Tapa…")
            case .notInstalled:
                Text("Tapa's background service isn't installed.")
            case .unreachable:
                Text("Tapa's background service isn't responding.")
            }

            Divider()
            Button("Open Tapa", action: openTapa)
                .keyboardShortcut("o")
            Button("Settings…") {
                openSettings()
                NSApp.activate()
            }
            .keyboardShortcut(",")
            Button("Quit Tapa") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func openTapa() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
