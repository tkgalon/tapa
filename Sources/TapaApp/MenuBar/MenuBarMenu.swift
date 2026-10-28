import AppKit
import SwiftUI
import TapaCore

/// The status item's panel: a quick Ascent at Basecamp, the time left and the way out during one,
/// then the window, Settings and Quit.
struct MenuBarMenu: View {
    @Environment(DaemonStore.self) private var daemon
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch daemon.connection {
            case .connected:
                if let snapshot = daemon.snapshot, snapshot.state != .basecamp {
                    AscentMenu(snapshot: snapshot, openTapa: openTapa)
                } else {
                    BasecampMenu(openTapa: openTapa)
                }
            case .connecting:
                notice("Connecting to Tapa…")
            case .notInstalled:
                notice("Tapa's background service isn't installed.")
            case .unreachable:
                notice("Tapa's background service isn't responding.")
            }

            PanelDivider()
            PanelButton("Open Tapa", trailing: Text(verbatim: "⌘O"), action: openTapa)
                .keyboardShortcut("o")
            PanelButton("Settings…", trailing: Text(verbatim: "⌘,")) {
                MenuBarPanel.close()
                openSettings()
                NSApp.activate()
            }
            .keyboardShortcut(",")
            PanelButton("Quit Tapa", trailing: Text(verbatim: "⌘Q")) { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(5)
        .frame(width: 300)
    }

    private func notice(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private func openTapa() {
        MenuBarPanel.close()
        openWindow(id: "main")
        NSApp.activate()
    }
}
