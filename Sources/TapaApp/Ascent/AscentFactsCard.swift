import SwiftUI

/// What's left behind and whether Rest Stops are open, one per row.
struct AscentFactsCard: View {
    let leaveBehind: Text
    let restStops: LocalizedStringKey

    var body: some View {
        VStack(spacing: 0) {
            row("Leave Behind") { leaveBehind }
            Divider()
            row("Rest Stops") { Text(restStops) }
        }
        .padding(.horizontal, 16)
        .glassBackground(in: .rect(cornerRadius: 12))
    }

    private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            value()
                .lineLimit(1)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }
}
