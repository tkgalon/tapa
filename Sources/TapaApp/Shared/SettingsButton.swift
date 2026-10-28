import AppKit
import SwiftUI

/// Settings from the photo screens, which have no header of their own. Round glass, like the
/// sidebar beside it.
struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            openSettings()
            NSApp.activate()
        } label: {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .frame(width: 30, height: 30)
                .glassBackground(in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }
}
