import SwiftUI
import TapaCore

/// The Ascent's end time. The choices open in a popover above the bar, inside the window, with
/// Other… for a time of one's own, like 10.30 when a meeting ends then.
struct EndTimeButton: View {
    @Binding var endAt: Date
    let choices: [Date]

    @Environment(AppRouter.self) private var router
    @State private var isPresented = false
    @State private var isChoosingOther = false

    var body: some View {
        Button {
            isChoosingOther = false
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
            if isChoosingOther {
                OtherEndTime(initial: endAt) { chosen in
                    endAt = chosen
                    isPresented = false
                } cancel: {
                    isPresented = false
                }
            } else {
                choiceList
            }
        }
        // Choose Time… in the menu bar opens the window with the choices showing.
        .onChange(of: router.isChoosingEndTime, initial: true) { _, isChoosing in
            guard isChoosing else { return }
            router.isChoosingEndTime = false
            isChoosingOther = false
            isPresented = true
        }
    }

    private var choiceList: some View {
        // Latest on top, so the times climb away from the bar the popover rises from.
        VStack(spacing: 2) {
            ForEach(choices.reversed(), id: \.self) { time in
                ChoiceRow(isSelected: time == endAt) {
                    endAt = time
                    isPresented = false
                } title: {
                    Text(time, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
            }
            Divider()
                .padding(.vertical, 2)
            ChoiceRow(isSelected: !choices.contains(endAt)) {
                isChoosingOther = true
            } title: {
                if choices.contains(endAt) {
                    Text("Other…")
                } else {
                    Text("Other: \(endAt, format: .dateTime.hour().minute())")
                        .monospacedDigit()
                }
            }
        }
        .padding(6)
        .frame(width: 148)
    }
}

/// A time of one's own, typed as 10.30, 10:30 or 1030. A time already past today means tomorrow,
/// within the 12 hours an Ascent may last.
private struct OtherEndTime: View {
    let set: (Date) -> Void
    let cancel: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(initial: Date, set: @escaping (Date) -> Void, cancel: @escaping () -> Void) {
        _text = State(initialValue: initial.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
        self.set = set
        self.cancel = cancel
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let endAt = Self.time(in: text).map { Self.endAt(hour: $0.hour, minute: $0.minute, after: context.date) }
            let length = endAt.map { $0.timeIntervalSince(context.date) }
            let isValid = length.map {
                (AscentStateMachine.minimumSessionLength...AscentStateMachine.maximumSessionLength).contains($0)
            } ?? false
            VStack(spacing: 8) {
                Text("Ends at")
                    .fontWeight(.semibold)
                // As wide as 00.00, since that's all it holds.
                // A capsule like Cancel and the bar's controls, outlined in glacier while typing.
                TextField("Ends at", text: $text, prompt: Text(verbatim: "00.00"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(.body.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(width: 56, height: 24)
                    .padding(.horizontal, 6)
                    .background(.quaternary, in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.glacier, lineWidth: 1.5)
                            .opacity(isFocused ? 1 : 0)
                    }
                    .focused($isFocused)
                    .onSubmit {
                        if isValid, let endAt { set(endAt) }
                    }
                Text(hint(length: length, isValid: isValid))
                    .font(.caption)
                    .foregroundStyle(isValid || length == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                HStack(spacing: 6) {
                    Button("Cancel", action: cancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Set") {
                        if let endAt { set(endAt) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.glacier)
                    .disabled(!isValid)
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
            .padding(12)
            .fixedSize()
        }
        .onAppear { isFocused = true }
    }

    private func hint(length: TimeInterval?, isValid: Bool) -> String {
        guard let length else { return String(localized: "Like 10.30") }
        guard isValid else { return String(localized: "15m to 12h") }
        let span = Duration.seconds(length)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .up)))
        return String(localized: "in \(span)")
    }

    /// Reads 10.30, 10:30, 1030 or 10 as an hour and a minute.
    static func time(in text: String) -> (hour: Int, minute: Int)? {
        let digits = text.filter(\.isNumber)
        let parts = text.split(whereSeparator: { $0 == "." || $0 == ":" })
        let hour: Int?
        let minute: Int?
        if parts.count == 2 {
            hour = Int(parts[0])
            minute = Int(parts[1])
        } else if digits.count == 3 || digits.count == 4 {
            hour = Int(digits.dropLast(2))
            minute = Int(digits.suffix(2))
        } else {
            hour = Int(digits)
            minute = 0
        }
        guard let hour, let minute, (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// The next time the clock shows the hour and minute.
    static func endAt(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current) -> Date {
        let parts = DateComponents(hour: hour, minute: minute)
        return calendar.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) ?? now
    }
}
