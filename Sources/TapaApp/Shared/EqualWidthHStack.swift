import SwiftUI

/// A row whose children all take the width of the widest one, like the segments of a segmented
/// control.
struct EqualWidthHStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = cellSize(for: subviews)
        return CGSize(width: size.width * CGFloat(subviews.count), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = cellSize(for: subviews)
        let proposal = ProposedViewSize(size)
        var centerX = bounds.minX + size.width / 2
        for subview in subviews {
            subview.place(at: CGPoint(x: centerX, y: bounds.midY), anchor: .center, proposal: proposal)
            centerX += size.width
        }
    }

    private func cellSize(for subviews: Subviews) -> CGSize {
        subviews
            .map { $0.sizeThatFits(.unspecified) }
            .reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
    }
}
