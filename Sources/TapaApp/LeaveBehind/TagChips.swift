import SwiftUI

/// Names as small tinted chips. Past `limit`, the rest fold into a "+N" chip, and the full list
/// shows on hover.
struct TagChips: View {
    let names: [String]
    var limit = 2

    var body: some View {
        HStack(spacing: 4) {
            ForEach(names.prefix(limit), id: \.self) { name in
                chip(Text(name))
            }
            if names.count > limit {
                chip(Text("+\(names.count - limit)"))
            }
        }
        .help(names.formatted(.list(type: .and)))
    }

    private func chip(_ label: Text) -> some View {
        label
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.glacierInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minHeight: 20)
            .background(Color.glacierTint, in: .capsule)
    }
}
