import SwiftUI

/// Today's screen time and focus at the foot of the sidebar. Shows dashes until the activity
/// tracker exists.
struct TodaySummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            row("Screen Time")
            row("Focused")
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: "–")
                .accessibilityLabel(Text("Not available yet"))
        }
        .font(.callout)
    }
}
