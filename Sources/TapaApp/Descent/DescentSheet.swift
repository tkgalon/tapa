import SwiftUI

/// Ending Summit Mode early: a reason, a held button, then a 30 second countdown that can still be
/// called off. The daemon only hears about it when the countdown ends.
struct DescentSheet: View {
    let descentsRemaining: Int
    let summitEndsAt: Date?

    @Environment(DaemonStore.self) private var daemon
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var isCountingDown = false
    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        Group {
            if descentsRemaining == 0 {
                NoDescentLeftView(summitEndsAt: summitEndsAt) { dismiss() }
            } else if isCountingDown {
                DescentCountdownView(reason: trimmedReason) {
                    isCountingDown = false
                } descend: {
                    descend()
                }
            } else {
                DescentReasonView(reason: $reason, descentsRemaining: descentsRemaining) {
                    isCountingDown = true
                } stay: {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .alert("Couldn't Descend", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func descend() {
        Task {
            do {
                try await daemon.useDescent(reason: trimmedReason)
                dismiss()
            } catch {
                isCountingDown = false
                failure = errorMessage(for: error)
                isShowingFailure = true
            }
        }
    }
}
