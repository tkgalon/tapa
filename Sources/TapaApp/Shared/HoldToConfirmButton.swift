import SwiftUI

/// A button that acts only after it's held for `duration`, filling up while held. VoiceOver users
/// activate it directly.
struct HoldToConfirmButton: View {
    enum Prominence {
        /// White text on Summit night, filling with glacier teal.
        case prominent
        /// A plain bordered button, filling with a quiet gray, for actions to discourage.
        case secondary
    }

    let title: LocalizedStringKey
    let duration: Double
    let prominence: Prominence
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHolding = false

    init(
        _ title: LocalizedStringKey,
        duration: Double = 3,
        prominence: Prominence = .prominent,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.duration = duration
        self.prominence = prominence
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Text(title)
            .fontWeight(prominence == .prominent ? .semibold : .regular)
            .foregroundStyle(prominence == .prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 20)
            .frame(minHeight: 32)
            .background {
                ZStack(alignment: .leading) {
                    track
                    fill
                        .scaleEffect(x: isHolding ? 1 : 0, anchor: .leading)
                }
            }
            .clipShape(.capsule)
            .overlay {
                if prominence == .secondary {
                    Capsule().strokeBorder(.separator)
                }
            }
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.45)
            .onLongPressGesture(minimumDuration: duration) {
                if isEnabled {
                    action()
                }
            } onPressingChanged: { pressing in
                withAnimation(pressing && isEnabled ? .linear(duration: duration) : .easeOut(duration: 0.2)) {
                    isHolding = pressing && isEnabled
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if isEnabled {
                    action()
                }
            }
    }

    @ViewBuilder
    private var track: some View {
        switch prominence {
        case .prominent: Color.summitNight
        case .secondary: Rectangle().fill(.background)
        }
    }

    @ViewBuilder
    private var fill: some View {
        switch prominence {
        case .prominent: Color.glacier
        case .secondary: Rectangle().fill(.quaternary)
        }
    }
}
