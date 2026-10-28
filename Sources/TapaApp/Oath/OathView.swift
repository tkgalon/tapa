import SwiftUI

/// The Summit Oath: what the user commits to, confirmed by holding a button.
struct OathView<When: View>: View {
    let message: LocalizedStringKey
    let footnote: LocalizedStringKey
    let websiteCount: Int
    let cancel: () -> Void
    let swear: () -> Void
    @ViewBuilder let when: When

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text(verbatim: "⚔️")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("The Summit Oath")
                        .font(.system(size: 28, weight: .bold))
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            OathTerms(websiteCount: websiteCount) { when }

            Label(footnote, systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                HoldToConfirmButton("Hold to Swear the Oath", action: swear)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(width: 520)
        .presentationBackground { BehindWindowMaterial() }
    }
}
