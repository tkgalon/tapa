import SwiftUI

/// A button that acts only after it's held for `duration`, filling up while held. VoiceOver users
/// activate it directly.
struct HoldToConfirmButton: View {
    let title: LocalizedStringKey
    let duration: Double
    let action: () -> Void

    @State private var isHolding = false

    init(_ title: LocalizedStringKey, duration: Double = 3, action: @escaping () -> Void) {
        self.title = title
        self.duration = duration
        self.action = action
    }

    var body: some View {
        Text(title)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 32)
            .background {
                ZStack(alignment: .leading) {
                    Color.summitNight
                    Color.glacier
                        .scaleEffect(x: isHolding ? 1 : 0, anchor: .leading)
                }
            }
            .clipShape(.capsule)
            .contentShape(.capsule)
            .onLongPressGesture(minimumDuration: duration) {
                action()
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) {
                    isHolding = pressing
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}
