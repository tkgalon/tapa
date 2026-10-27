import SwiftUI

/// One option in a popover list: a check and the selection fill when chosen, a light fill on hover.
struct ChoiceRow<Title: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let title: Title

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                title
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(fill, in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if isSelected {
            AnyShapeStyle(.tint)
        } else if isHovering {
            AnyShapeStyle(.quaternary)
        } else {
            AnyShapeStyle(.clear)
        }
    }
}
