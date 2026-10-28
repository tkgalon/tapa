import SwiftUI

/// Why the user wants down. Staying is the default; descending takes a written reason and a hold.
struct DescentReasonView: View {
    @Binding var reason: String
    let descentsRemaining: Int
    let begin: () -> Void
    let stay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Descend Early?")
                    .font(.title3.bold())
                Text("""
                    A Descent is for things that can't wait. It ends Summit Mode now and uses 1 of \
                    your \(descentsRemaining) left this week.
                    """)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What needs you right now?")
                    .fontWeight(.medium)
                TextEditor(text: $reason)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 88)
                    .background(.background, in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.separator)
                    }
                    .accessibilityLabel("What needs you right now?")
            }

            Text("Your reason stays in your Trail Log on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                HoldToConfirmButton(
                    "Hold 3 Seconds to Descend",
                    prominence: .secondary,
                    isEnabled: !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: begin
                )
                Spacer()
                Button("Stay on Your Path", action: stay)
                    .buttonStyle(.borderedProminent)
                    .tint(.glacier)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
    }
}
