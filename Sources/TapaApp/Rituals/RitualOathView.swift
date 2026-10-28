import SwiftUI
import TapaCore

/// The Summit Oath for a Ritual, taken once when it's saved or turned on.
struct RitualOathView: View {
    let ritual: Ritual
    let cancel: () -> Void
    let swear: () -> Void

    @Environment(DaemonStore.self) private var daemon

    var body: some View {
        OathView(
            message: """
                Hear my words and bear witness. Each time \(ritual.name) begins, I leave these \
                distractions at the foot of the mountain, and I shall not seek them until it ends.
                """,
            footnote: "Changing it later asks for the Oath again, and it can't change while it runs.",
            websiteCount: daemon.config.websiteCount(in: ritual.leaveBehindIDs),
            cancel: cancel,
            swear: swear
        ) {
            OathTermRow(title: "Runs", systemImage: "calendar") {
                Text(ritual.schedule())
                    .monospacedDigit()
            }
        }
    }
}
