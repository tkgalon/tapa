import SwiftUI

/// Shown in place of the Ascent bar while the daemon can't be reached.
struct ConnectionNotice: View {
    let connection: DaemonStore.Connection

    var body: some View {
        Group {
            switch connection {
            case .connecting, .connected:
                ProgressView()
                    .controlSize(.small)
            case .notInstalled:
                Label("Tapa's background service isn't installed. Run scripts/install.sh.", systemImage: "wrench")
            case .unreachable:
                Label("Tapa's background service isn't responding.", systemImage: "exclamationmark.triangle")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .glassBackground(in: .capsule)
    }
}
