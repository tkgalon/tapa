import SwiftUI
import TapaCore

/// The mode in a capsule, dark for Summit Mode's commitment and light for the Trail.
struct AscentModeChip: View {
    let mode: SessionMode
    let isRestStop: Bool
    let ritualName: String?

    var body: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(mode == .summit && !isRestStop ? Color.white : Color.glacierInk)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)
            .background(mode == .summit && !isRestStop ? Color.summitNight : Color.glacierTint, in: .capsule)
    }

    private var title: String {
        let base: String
        if isRestStop {
            base = String(localized: "☕️ Rest Stop")
        } else {
            base = mode == .summit ? String(localized: "🏔️ Summit Mode") : String(localized: "🥾 Trail")
        }
        guard let ritualName, !isRestStop else { return base }
        return "\(base) · \(ritualName)"
    }
}
