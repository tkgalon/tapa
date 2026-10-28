import SwiftUI

/// Full-bleed photo, the next Ritual in the sky, and one glass bar to begin an Ascent.
struct BasecampView: View {
    @Environment(DaemonStore.self) private var daemon

    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            PhotoBackdrop(photo: .basecamp)

            VStack(spacing: 0) {
                TimelineView(.everyMinute) { context in
                    UpNextView(upcoming: daemon.upNext(after: context.date), now: context.date, scale: scale)
                }
                .padding(.top, 48 * scale)

                Spacer()

                if daemon.connection == .connected {
                    AscentBar()
                } else {
                    ConnectionNotice(connection: daemon.connection)
                }
            }
            .padding(.bottom, 32 * scale)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            HeroScale.factor(for: proxy.size)
        } action: { factor in
            scale = factor
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if let snapshot = daemon.snapshot {
                    Text("^[\(snapshot.descentsRemaining) Descent](inflect: true) left this week")
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 28)
                        .glassBackground(in: .capsule)
                }
                SettingsButton()
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
            .ignoresSafeArea(edges: .top)
        }
    }
}
