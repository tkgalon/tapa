import SwiftUI
import TapaCore

/// The running Ascent: the time left over the summit photo.
struct AscentView: View {
    let snapshot: SessionSnapshot

    @Environment(DaemonStore.self) private var daemon

    @State private var scale: CGFloat = 1
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        ZStack {
            PhotoBackdrop(photo: .summit)

            VStack(spacing: 4) {
                Text(modeTitle)
                    .font(.system(size: 13 * scale, weight: .semibold))
                if let endsAt = snapshot.endsAt {
                    TimelineView(.everyMinute) { context in
                        Text(remaining(until: endsAt, from: context.date))
                            .font(.system(size: 72 * scale, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text("until \(endsAt, format: .dateTime.hour().minute())")
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
            controls
                .padding(.bottom, 32 * scale)
        }
        .photoToolbar()
        .alert("Couldn't End the Trail", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var modeTitle: LocalizedStringKey {
        switch (snapshot.state, snapshot.mode) {
        case (.restStop, _): "☕️ Rest Stop"
        case (_, .summit): "🏔️ Summit Mode"
        default: "🥾 Trail"
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            if snapshot.mode == .trail {
                Button("End Trail", action: endTrail)
            }
            Text("^[\(snapshot.descentsRemaining) Descent](inflect: true) left this week")
                .foregroundStyle(.secondary)
        }
        .controlSize(.large)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .glassBackground(in: .capsule)
    }

    private func remaining(until endsAt: Date, from now: Date) -> String {
        Duration.seconds(max(endsAt.timeIntervalSince(now), 0))
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func endTrail() {
        let trails = snapshot.activeSessions.filter { $0.mode == .trail }
        Task {
            do {
                for session in trails {
                    try await daemon.endTrail(sessionID: session.id)
                }
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
