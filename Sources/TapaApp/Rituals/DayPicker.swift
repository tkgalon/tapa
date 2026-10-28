import SwiftUI
import TapaCore

/// The days a Ritual runs, one capsule per day in the calendar's order.
struct DayPicker: View {
    @Binding var days: Set<Weekday>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.week(), id: \.self) { day in
                let isSelected = days.contains(day)
                Button {
                    days[contains: day].toggle()
                } label: {
                    Text(day.shortName())
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .frame(minWidth: 40, minHeight: 26)
                        .background(
                            isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: .capsule
                        )
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Days")
    }
}
