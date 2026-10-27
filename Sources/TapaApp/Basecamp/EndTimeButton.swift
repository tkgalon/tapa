import SwiftUI

/// The Ascent's end time. The choices open in a popover above the bar, inside the window.
struct EndTimeButton: View {
    @Binding var endAt: Date
    let choices: [Date]

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(endAt, format: .dateTime.hour().minute())
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
        }
        .accessibilityLabel(Text("Until \(endAt, format: .dateTime.hour().minute())"))
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(spacing: 2) {
                ForEach(choices, id: \.self) { time in
                    ChoiceRow(isSelected: time == endAt) {
                        endAt = time
                        isPresented = false
                    } title: {
                        Text(time, format: .dateTime.hour().minute())
                            .monospacedDigit()
                    }
                }
            }
            .padding(6)
            .frame(width: 128)
        }
    }
}
