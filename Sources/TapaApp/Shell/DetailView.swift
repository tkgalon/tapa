import SwiftUI
import TapaCore

struct DetailView: View {
    let item: SidebarItem

    @Environment(DaemonStore.self) private var daemon

    var body: some View {
        switch item {
        case .basecamp:
            if let snapshot = daemon.snapshot, snapshot.state != .basecamp {
                AscentView(snapshot: snapshot)
            } else {
                BasecampView()
            }
        case .leaveBehind:
            LeaveBehindView()
        case .rituals, .trailLog:
            ContentUnavailableView(
                String(localized: item.title),
                systemImage: item.systemImage,
                description: Text("This screen arrives in a later step.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
