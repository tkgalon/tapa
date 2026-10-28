import SwiftUI
import TapaCore

/// Summit Mode or Trail. A segmented control whose selection slides between the two, where the
/// system one jumps.
struct ModePicker: View {
    @Binding var mode: SessionMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection

    var body: some View {
        EqualWidthHStack {
            segment(.trail, title: "🥾 Trail")
            segment(.summit, title: "🏔️ Summit Mode")
        }
        .padding(2)
        .background(.quaternary, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode")
    }

    private func segment(_ value: SessionMode, title: LocalizedStringKey) -> some View {
        let isSelected = mode == value
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                mode = value
            }
        } label: {
            Text(title)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.tint)
                            .matchedGeometryEffect(id: "selection", in: selection)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
