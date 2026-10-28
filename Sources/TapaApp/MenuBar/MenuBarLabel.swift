import SwiftUI
import TapaCore

/// The status item: a monochrome symbol for the state, and the time left when the user wants it.
/// It also keeps the daemon polled, since it lives as long as the app, window or not.
struct MenuBarLabel: View {
    @Environment(DaemonStore.self) private var daemon
    @AppStorage(MenuBarPreferences.showsTimeKey) private var showsTime = true

    @State private var now = Date.now

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            if showsTime, let remaining {
                Text(remaining)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Tapa, \(stateName)"))
        .task { await daemon.run() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                now = .now
            }
        }
    }

    private var symbol: String {
        switch (daemon.snapshot?.state, daemon.snapshot?.mode) {
        case (.restStop?, _): "cup.and.saucer"
        case (.ascent?, .summit?): "mountain.2.fill"
        case (.ascent?, _): "figure.hiking"
        default: "mountain.2"
        }
    }

    private var stateName: String {
        switch (daemon.snapshot?.state, daemon.snapshot?.mode) {
        case (.restStop?, _): String(localized: "Rest Stop")
        case (.ascent?, .summit?): String(localized: "Summit Mode")
        case (.ascent?, _): String(localized: "Trail")
        default: String(localized: "Basecamp")
        }
    }

    /// Minutes and seconds in a Rest Stop, hours and minutes in an Ascent, nothing at Basecamp.
    private var remaining: String? {
        guard let snapshot = daemon.snapshot else { return nil }
        if snapshot.state == .restStop, let end = snapshot.restStop?.endAt {
            return Duration.seconds(max(end.timeIntervalSince(now), 0)).formatted(.time(pattern: .minuteSecond))
        }
        guard snapshot.state == .ascent, let end = snapshot.endsAt else { return nil }
        return Duration.seconds(max(end.timeIntervalSince(now), 0))
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .up)))
    }
}

enum MenuBarPreferences {
    static let showsTimeKey = "showsTimeInMenuBar"
    static let quickModeKey = "quickAscentMode"
    static let quickListsKey = "quickAscentLists"
}
