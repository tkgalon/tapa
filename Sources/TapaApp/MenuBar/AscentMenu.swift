import SwiftUI
import TapaCore

/// The running Ascent: its mode, the time left with how far along it is, and its Ritual and lists,
/// then a Rest Stop or the end of a Trail, or the Descent in Summit Mode.
struct AscentMenu: View {
    let snapshot: SessionSnapshot
    let openTapa: () -> Void

    @Environment(DaemonStore.self) private var daemon
    @Environment(AppRouter.self) private var router
    @AppStorage(MenuBarPreferences.showsTimeKey) private var showsTime = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header(at: context.date)
                PanelDivider()
                actions(at: context.date)
                PanelDivider()
                PanelButton("Show Time in Menu Bar", isChecked: showsTime) { showsTime.toggle() }
            }
        }
    }

    // MARK: Header

    private func header(at now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .fontWeight(.semibold)
            if let target = countdownTarget {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(remaining(until: target, from: now))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("until \(target.formatted(.dateTime.hour().minute()))")
                        .foregroundStyle(.secondary)
                }
            }
            if let progress = progress(at: now) {
                // A thin line, as in the mockup. The system bar is twice as thick.
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            // A fixed ink: .primary turns grey under the panel's vibrancy.
                            Capsule()
                                .fill(Color.glacierInk)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .accessibilityHidden(true)
            }
            if let details {
                Text(details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private var heading: String {
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): String(localized: "☕️ Rest Stop")
        case (_, .summit): String(localized: "🏔️ Summit Mode")
        default: String(localized: "🥾 Trail")
        }
    }

    /// The Ritual that started it, then the lists it leaves behind.
    private var details: String? {
        let lists = daemon.activeLists.map(\.name).formatted(.list(type: .and))
        let parts = [daemon.runningRitualName, lists.isEmpty ? nil : lists].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var countdownTarget: Date? {
        snapshot.state == .restStop ? snapshot.restStop?.endAt : snapshot.endsAt
    }

    /// Minutes and seconds in a Rest Stop, hours and minutes in an Ascent, rounded up so it never
    /// reads 0m while time is left.
    private func remaining(until target: Date, from now: Date) -> String {
        let left = Duration.seconds(max(target.timeIntervalSince(now), 0))
        if snapshot.state == .restStop {
            return left.formatted(.time(pattern: .minuteSecond))
        }
        return left.formatted(.units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .up)))
    }

    private func progress(at now: Date) -> Double? {
        let interval: DateInterval?
        if snapshot.state == .restStop, let stop = snapshot.restStop {
            interval = DateInterval(start: stop.startAt, end: max(stop.endAt, stop.startAt))
        } else if let start = snapshot.activeSessions.map(\.startAt).min(), let end = snapshot.endsAt, end > start {
            interval = DateInterval(start: start, end: end)
        } else {
            interval = nil
        }
        guard let interval, interval.duration > 0 else { return nil }
        return min(max(now.timeIntervalSince(interval.start) / interval.duration, 0), 1)
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(at now: Date) -> some View {
        if snapshot.mode == .summit {
            PanelButton("☕️ Take a Rest Stop", trailing: Text("Off in Summit Mode")) {}
                .disabled(true)
            PanelButton("Descent…", trailing: Text("\(snapshot.descentsRemaining) left this week")) {
                router.showDescent()
                openTapa()
            }
        } else {
            restStop(at: now)
            PanelButton("End Trail") {
                perform { try await daemon.endTrails() }
            }
        }
    }

    @ViewBuilder
    private func restStop(at now: Date) -> some View {
        switch snapshot.restStopPhase(at: now) {
        case .closed:
            let wait = Duration.seconds(snapshot.restStopWait).formatted(.units(width: .narrow))
            PanelButton("☕️ Take a Rest Stop", trailing: Text("after \(wait)")) {
                perform(closing: false) { try await daemon.requestRestStop() }
            }
        case .waiting(let readyAt):
            let seconds = max(Int(readyAt.timeIntervalSince(now).rounded(.up)), 0)
            PanelButton("☕️ Take a Rest Stop", trailing: Text("Available in \(seconds)s")) {}
                .disabled(true)
        case .ready:
            PanelHeading("☕️ Rest Stop, how long?")
            ForEach([1, 3, 5, 10, 15], id: \.self) { minutes in
                let length = Duration.seconds(minutes * 60).formatted(.units(allowed: [.minutes], width: .wide))
                PanelButton(title: Text(length)) {
                    perform { try await daemon.startRestStop(length: TimeInterval(minutes * 60)) }
                }
            }
        case .open:
            PanelButton("End Rest Stop") {
                perform { try await daemon.endRestStop() }
            }
        }
    }

    /// Asking for a Rest Stop keeps the panel open, so the wait can be watched.
    private func perform(closing: Bool = true, _ change: @escaping () async throws -> Void) {
        if closing {
            MenuBarPanel.close()
        }
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
