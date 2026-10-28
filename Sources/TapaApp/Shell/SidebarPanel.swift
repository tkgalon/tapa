import SwiftUI

/// A glass sidebar that floats over the content. Over a photo it's only as tall as its items, so
/// the photo shows below it. On other screens it runs the full height, with Today at its foot.
struct SidebarPanel: View {
    static let width: CGFloat = 208
    static let margin: CGFloat = 8
    static var occupiedWidth: CGFloat { width + margin * 2 }

    /// Room at the top for the window controls and the sidebar button.
    private static let windowControlsHeight: CGFloat = 40
    private static let heightAnimation = Animation.snappy(duration: 0.25)

    @Binding var selection: SidebarItem?
    let isFullHeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarRow(item: item, isSelected: item == selection) {
                        selection = item
                    }
                }
            }
            if isFullHeight {
                Spacer(minLength: 0)
            }
            TodaySummary()
        }
        .padding(.top, Self.windowControlsHeight)
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
        .frame(width: Self.width)
        .frame(maxHeight: isFullHeight ? .infinity : nil, alignment: .top)
        .glassBackground(in: .rect(cornerRadius: 16))
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand(perform: move)
        .padding(Self.margin)
        .ignoresSafeArea(edges: .top)
        // On the whole panel, so the glass grows with its contents instead of jumping ahead.
        .animation(Self.heightAnimation, value: isFullHeight)
    }

    private func move(_ direction: MoveCommandDirection) {
        let items = SidebarItem.allCases
        guard let current = selection.flatMap(items.firstIndex) else { return }
        switch direction {
        case .up: selection = items[max(current - 1, 0)]
        case .down: selection = items[min(current + 1, items.count - 1)]
        default: break
        }
    }
}
