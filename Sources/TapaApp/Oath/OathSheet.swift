import SwiftUI
import TapaCore

/// The last step before Summit Mode: what the user commits to, confirmed by holding a button.
struct OathSheet: View {
    let request: StartRequest

    @Environment(DaemonStore.self) private var daemon
    @Environment(\.dismiss) private var dismiss

    @State private var failure: String?
    @State private var isShowingFailure = false

    var body: some View {
        VStack(spacing: 0) {
            Photo.summit.image
                .resizable()
                .scaledToFill()
                .frame(height: 196)
                .clipped()
                .mask {
                    LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
                }
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("The Summit Oath")
                        .font(.system(size: 28, weight: .bold))
                    Text("""
                        You're about to begin a committed ascent. Once started, your focus rules stay active \
                        until the scheduled end time.
                        """)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OathTerms(request: request, websiteCount: websiteCount)

                Label("Your commitment can't be changed during the ascent.", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    HoldToConfirmButton("Hold to Take the Oath", action: takeOath)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .offset(y: -24)
            .padding(.bottom, -24)
        }
        .frame(width: 520)
        .alert("Couldn't Begin Summit Mode", isPresented: $isShowingFailure, presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var websiteCount: Int {
        Set(
            daemon.config.leaveBehindLists
                .filter { request.leaveBehindIDs.contains($0.id) }
                .flatMap(\.domains)
        ).count
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
