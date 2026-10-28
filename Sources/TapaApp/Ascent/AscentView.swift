import SwiftUI
import TapaCore

/// The running Ascent: the time left over the summit photo, its progress, and the way down.
struct AscentView: View {
    let snapshot: SessionSnapshot

    @Environment(DaemonStore.self) private var daemon

    @State private var scale: CGFloat = 1
    @State private var isShowingDescent = false
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        ZStack {
            PhotoBackdrop(photo: .summit)

            VStack(spacing: 4) {
                Text(modeTitle)
                    .font(.system(size: 13 * scale, weight: .semibold))
                if let target = countdownTarget {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(remaining(until: target, from: context.date))
                            .font(.system(size: 72 * scale, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text(countdownCaption(for: target))
                        .font(.system(size: 17 * scale, design: .serif))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: Color(red: 0.02, green: 0.08, blue: 0.19).opacity(0.45), radius: 8, y: 1)
            .accessibilityElement(children: .combine)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            HeroScale.factor(for: proxy.size)
        } action: { factor in
            scale = factor
        }
        .overlay(alignment: .bottom) {
            if let startAt, let endAt = snapshot.endsAt {
                AscentProgressCard(
                    startAt: startAt,
                    endAt: endAt,
                    leaveBehind: leaveBehindSummary,
                    restStops: restStopsSummary
                )
                .padding(.bottom, 32 * scale)
            }
        }
        .overlay(alignment: .topTrailing) {
            actions
                .padding(.top, 12)
                .padding(.trailing, 16)
                .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $isShowingDescent) {
            DescentSheet(descentsRemaining: snapshot.descentsRemaining, summitEndsAt: snapshot.endsAt)
        }
        .alert("Couldn't Change the Ascent", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    /// Top right, where the critical action sits on every Mac window, as Basecamp's badge does.
    private var actions: some View {
        HStack(spacing: 8) {
            if snapshot.mode == .summit {
                Button {
                    isShowingDescent = true
                } label: {
                    Text("Descent… \(Text("\(snapshot.descentsRemaining) left").foregroundStyle(.secondary))")
                }
                .help("End Summit Mode early")
            } else {
                if snapshot.state != .restStop {
                    Button("☕️ Take a Rest Stop", action: takeRestStop)
                }
                Button("End Trail", action: endTrail)
            }
        }
        .buttonStyle(.glassIfAvailable)
    }

    private var modeTitle: LocalizedStringKey {
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): "☕️ Rest Stop"
        case (_, .summit): "🏔️ Summit Mode"
        default: "🥾 Trail"
        }
    }

    /// During a Rest Stop the countdown is to the end of the stop, otherwise to the end of the Ascent.
    private var countdownTarget: Date? {
        snapshot.state == .restStop ? snapshot.restStop?.endAt : snapshot.endsAt
    }

    private func countdownCaption(for target: Date) -> String {
        let time = target.formatted(.dateTime.hour().minute())
        return snapshot.state == .restStop
            ? String(localized: "back on the Trail at \(time)")
            : String(localized: "to the summit, at \(time)")
    }

    private var startAt: Date? {
        snapshot.activeSessions.map(\.startAt).min()
    }

    private var leaveBehindSummary: Text {
        let ids = Set(snapshot.activeSessions.flatMap(\.leaveBehindIDs))
        let lists = daemon.config.leaveBehindLists.filter { ids.contains($0.id) }
        let websites = Set(lists.flatMap(\.domains)).count
        let names = lists.map(\.name).formatted(.list(type: .and))
        return Text("\(names) · ^[\(websites) website](inflect: true)")
    }

    private var restStopsSummary: LocalizedStringKey {
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): "Taking one now"
        case (_, .summit): "Off in Summit Mode"
        default: "5 minutes, when you need one"
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

    private func takeRestStop() {
        perform { try await daemon.requestRestStop() }
    }

    private func endTrail() {
        let trails = snapshot.activeSessions.filter { $0.mode == .trail }
        perform {
            for session in trails {
                try await daemon.endTrail(sessionID: session.id)
            }
        }
    }

    private func perform(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
