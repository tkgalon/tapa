import SwiftUI
import TapaCore

/// The running Ascent: the time left over the summit photo, its progress, and the way down.
struct AscentView: View {
    let snapshot: SessionSnapshot

    @Environment(DaemonStore.self) private var daemon
    @Environment(AppRouter.self) private var router

    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            PhotoBackdrop(photo: .summit)

            // Darkens the foot of the photo, like the mist in the mockup, so the white text reads.
            LinearGradient(
                colors: [.clear, Color(red: 0.02, green: 0.08, blue: 0.19).opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16 * scale) {
                AscentModeChip(
                    mode: snapshot.mode ?? .trail,
                    isRestStop: snapshot.state == .restStop,
                    ritualName: daemon.runningRitualName
                )

                if let target = countdownTarget {
                    VStack(alignment: .leading, spacing: 0) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            // Proportional digits: tabular ones centre a narrow 1 in a wide slot, which
                            // pulls the left edge in from the caption below.
                            Text(remaining(until: target, from: context.date))
                                .font(.system(size: 72 * scale, weight: .semibold, design: .rounded))
                        }
                        Text(countdownCaption(for: target))
                            .font(.system(size: 20 * scale, design: .serif))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: Color(red: 0.02, green: 0.08, blue: 0.19).opacity(0.45), radius: 8, y: 1)
                    .accessibilityElement(children: .combine)
                }

                if let startAt, let endAt = snapshot.endsAt {
                    AscentProgress(startAt: startAt, endAt: endAt, isSummit: snapshot.mode == .summit)
                }

                AscentFactsCard(leaveBehind: leaveBehindSummary, restStops: restStopsSummary)
            }
            .frame(maxWidth: 620 * scale)
            .padding(.horizontal, 32)
            .padding(.bottom, 32 * scale)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            HeroScale.factor(for: proxy.size)
        } action: { factor in
            scale = factor
        }
        .overlay(alignment: .topTrailing) {
            actions
                .padding(.top, 12)
                .padding(.trailing, 16)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// Top right, where the critical action sits on every Mac window, as Basecamp's badge does.
    private var actions: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                if snapshot.mode == .summit {
                    Button {
                        router.showDescent()
                    } label: {
                        Text("Descent… \(Text("\(snapshot.descentsRemaining) left").foregroundStyle(.secondary))")
                    }
                    .help("End Summit Mode early")
                } else {
                    restStopActions(at: context.date)
                    Button("End Trail", action: endTrail)
                }
                SettingsButton()
            }
            .buttonStyle(.glassIfAvailable)
        }
    }

    @ViewBuilder
    private func restStopActions(at now: Date) -> some View {
        switch snapshot.restStopPhase(at: now) {
        case .closed:
            Button("☕️ Take a Rest Stop") {
                perform { try await daemon.requestRestStop() }
            }
        case .waiting(let readyAt):
            Button("☕️ Available in \(secondsLeft(until: readyAt, from: now))s") {}
                .disabled(true)
        case .ready:
            // Styled as a button so it matches End Trail beside it.
            RestStopMenu { length in
                perform { try await daemon.startRestStop(length: length) }
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
        case .open:
            Button("End Rest Stop", action: endRestStop)
        }
    }

    /// During a Rest Stop the countdown is to the end of the stop, otherwise to the end of the Ascent.
    private var countdownTarget: Date? {
        snapshot.state == .restStop ? snapshot.restStop?.endAt : snapshot.endsAt
    }

    private func countdownCaption(for target: Date) -> String {
        let time = target.formatted(.dateTime.hour().minute())
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): return String(localized: "back on the Trail at \(time)")
        case (_, .summit): return String(localized: "to the summit, at \(time)")
        default: return String(localized: "left on the Trail, until \(time)")
        }
    }

    private var startAt: Date? {
        snapshot.activeSessions.map(\.startAt).min()
    }

    private var leaveBehindSummary: Text {
        let lists = daemon.activeLists
        let websites = daemon.config.websiteCount(in: Set(lists.map(\.id)))
        let names = lists.map(\.name).formatted(.list(type: .and))
        return Text("\(names) · ^[\(websites) website](inflect: true)")
    }

    private var restStopsSummary: LocalizedStringKey {
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): "Taking one now"
        case (_, .summit): "Off in Summit Mode"
        default: "After a wait of \(Duration.seconds(snapshot.restStopWait).formatted(.units(width: .wide)))"
        }
    }

    /// Minutes and seconds for a Rest Stop. Hours and minutes for an Ascent, rounded up so it never
    /// reads 0m while time is left.
    private func remaining(until target: Date, from now: Date) -> String {
        let left = Duration.seconds(max(target.timeIntervalSince(now), 0))
        if snapshot.state == .restStop {
            return left.formatted(.time(pattern: .minuteSecond))
        }
        return left.formatted(.units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .up)))
    }

    private func endRestStop() {
        perform { try await daemon.endRestStop() }
    }

    private func secondsLeft(until date: Date, from now: Date) -> Int {
        max(Int(date.timeIntervalSince(now).rounded(.up)), 0)
    }

    private func endTrail() {
        perform { try await daemon.endTrails() }
    }

    private func perform(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch {
                router.report(error)
            }
        }
    }
}
