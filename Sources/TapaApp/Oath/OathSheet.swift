import SwiftUI
import TapaCore

/// The last step before Summit Mode starts by hand.
struct OathSheet: View {
    let request: StartRequest

    @Environment(DaemonStore.self) private var daemon
    @Environment(\.dismiss) private var dismiss

    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        OathView(
            message: """
                Hear my words and bear witness. I leave these distractions at the foot of the \
                mountain, and I shall not seek them until my watch is ended.
                """,
            footnote: "Your commitment can't be changed during the ascent.",
            websiteCount: daemon.config.websiteCount(in: request.leaveBehindIDs)
        ) {
            dismiss()
        } swear: {
            takeOath()
        } when: {
            OathTermRow(title: "Ends", systemImage: "clock") {
                TimelineView(.everyMinute) { context in
                    Text("\(request.endAt, format: .dateTime.hour().minute()) · in \(remaining(at: context.date))")
                        .monospacedDigit()
                }
            }
        }
        .alert("Couldn't Begin Summit Mode", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private func remaining(at now: Date) -> String {
        Duration.seconds(max(request.endAt.timeIntervalSince(now), 0))
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func takeOath() {
        let sworn = StartRequest(
            mode: request.mode,
            endAt: request.endAt,
            leaveBehindIDs: request.leaveBehindIDs,
            oathTaken: true
        )
        Task {
            do {
                try await daemon.start(sworn)
                dismiss()
            } catch {
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
