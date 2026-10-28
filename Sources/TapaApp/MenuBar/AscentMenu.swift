import SwiftUI
import TapaCore

/// The running Ascent: its mode, time left and lists, then a Rest Stop or the end of a Trail, or the
/// Descent in Summit Mode.
struct AscentMenu: View {
    let snapshot: SessionSnapshot
    let openTapa: () -> Void

    @Environment(DaemonStore.self) private var daemon
    @Environment(AppRouter.self) private var router
    @AppStorage(MenuBarPreferences.showsTimeKey) private var showsTime = true

    var body: some View {
        Text(heading)
        if let timeLeft {
            Text(timeLeft)
        }
        if !daemon.activeLists.isEmpty {
            leaveBehind
        }
        Divider()

        if snapshot.mode == .summit {
            Button("Descent… (\(snapshot.descentsRemaining) left this week)") {
                router.showDescent()
                openTapa()
            }
        } else {
            switch snapshot.restStopPhase(at: .now) {
            case .closed:
                Button("☕️ Take a Rest Stop") {
                    perform { try await daemon.requestRestStop() }
                }
            case .waiting(let readyAt):
                Text("☕️ Rest Stop available at \(readyAt.formatted(.dateTime.hour().minute().second()))")
            case .ready:
                RestStopMenu { length in
                    perform { try await daemon.startRestStop(length: length) }
                }
            case .open:
                Button("End Rest Stop") {
                    perform { try await daemon.endRestStop() }
                }
            }
            Button("End Trail") {
                perform { try await daemon.endTrails() }
            }
        }
        Divider()

        Toggle("Show Time in Menu Bar", isOn: $showsTime)
    }

    private var heading: String {
        let mode = switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): String(localized: "☕️ Rest Stop")
        case (_, .summit): String(localized: "🏔️ Summit Mode")
        default: String(localized: "🥾 Trail")
        }
        return [mode, daemon.runningRitualName].compactMap(\.self).joined(separator: " · ")
    }

    private var timeLeft: String? {
        let target = snapshot.state == .restStop ? snapshot.restStop?.endAt : snapshot.endsAt
        guard let target else { return nil }
        let left = Duration.seconds(max(target.timeIntervalSinceNow, 0))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated, fractionalPart: .hide(rounded: .up)))
        return String(localized: "\(left) left, until \(target.formatted(.dateTime.hour().minute()))")
    }

    private var leaveBehind: Text {
        let lists = daemon.activeLists
        let count = daemon.config.websiteCount(in: Set(lists.map(\.id)))
        let names = lists.map(\.name).formatted(.list(type: .and))
        return Text("\(names) · ^[\(count) website](inflect: true)")
    }

    private func perform(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch {
                router.report(error)
                openTapa()
            }
        }
    }
}
