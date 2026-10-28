import SwiftUI

/// The Ascent drawn as a trail: walked behind you, dashed ahead, a tick on every hour, and a flag
/// at the end. The start and end times sit beneath.
struct AscentProgress: View {
    let startAt: Date
    let endAt: Date
    /// Summit Mode ends at the summit; a Trail just ends.
    let isSummit: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 4) {
                AscentTrail(now: context.date, progress: progress(at: context.date), hours: hourMarks)
                    .accessibilityElement()
                    .accessibilityLabel("Progress")
                    .accessibilityValue(
                        Text(progress(at: context.date), format: .percent.precision(.fractionLength(0)))
                    )
                HStack {
                    Text("Started \(startAt, format: .dateTime.hour().minute())")
                    Spacer()
                    if isSummit {
                        Text("Summit \(endAt, format: .dateTime.hour().minute())")
                    } else {
                        Text("Ends \(endAt, format: .dateTime.hour().minute())")
                    }
                }
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
            }
        }
    }

    /// Every whole hour strictly between the start and the end, with where it falls on the trail.
    private var hourMarks: [AscentTrail.HourMark] {
        let calendar = Calendar.current
        var marks: [AscentTrail.HourMark] = []
        var next = calendar.nextDate(
            after: startAt,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
        while let hour = next, hour < endAt {
            marks.append(AscentTrail.HourMark(date: hour, fraction: fraction(of: hour)))
            next = calendar.date(byAdding: .hour, value: 1, to: hour)
        }
        return marks
    }

    private func progress(at now: Date) -> Double {
        min(max(fraction(of: now), 0), 1)
    }

    private func fraction(of date: Date) -> Double {
        let total = endAt.timeIntervalSince(startAt)
        guard total > 0 else { return 1 }
        return date.timeIntervalSince(startAt) / total
    }
}

private struct AscentTrail: View {
    struct HourMark: Identifiable {
        let date: Date
        let fraction: Double

        var id: Date { date }
    }

    let now: Date
    let progress: Double
    let hours: [HourMark]

    private let lineY: CGFloat = 30
    private let flagWidth: CGFloat = 14
    /// Each hour label needs this much room, or the labels crowd into one another.
    private let minimumMarkSpacing: CGFloat = 40
    /// Steps that divide a day evenly, so the marks land on the same hours every day.
    private static let hourSteps = [1, 2, 3, 4, 6, 12]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let length = width - flagWidth
            let walked = length * progress

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: walked, y: lineY))
                    path.addLine(to: CGPoint(x: length, y: lineY))
                }
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))

                ForEach(marks(fitting: length)) { mark in
                    let isPassed = mark.fraction <= progress
                    Capsule()
                        .fill(.white.opacity(isPassed ? 0.9 : 0.5))
                        .frame(width: 1.5, height: 12)
                        .position(x: length * mark.fraction, y: lineY)
                    Text(mark.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(isPassed ? 0.85 : 0.6))
                        .position(x: length * mark.fraction, y: lineY + 18)
                }

                Capsule()
                    .fill(.white)
                    .frame(width: max(walked, 6), height: 6)
                    .position(x: max(walked, 6) / 2, y: lineY)

                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .position(x: 5, y: lineY)

                Image(systemName: "flag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: flagWidth, height: 16, alignment: .bottomLeading)
                    .position(x: length + flagWidth / 2, y: lineY - 8)

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .padding(3)
                    .background(Color.glacier, in: .circle)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .position(x: walked, y: lineY)

                Text("You're here · \(now, format: .dateTime.hour().minute())")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .fixedSize()
                    .alignmentGuide(.leading) { label in
                        -min(max(walked - label.width / 2, 0), width - label.width)
                    }
            }
        }
        .frame(height: 56)
    }

    /// Every hour when there's room, otherwise every few hours, on the hours the step divides.
    private func marks(fitting length: CGFloat) -> [HourMark] {
        guard hours.count > 1, let first = hours.first, let last = hours.last else { return hours }
        let hourWidth = length * (last.fraction - first.fraction) / CGFloat(hours.count - 1)
        let step = Self.hourSteps.first { hourWidth * CGFloat($0) >= minimumMarkSpacing } ?? 24
        return hours.filter { Calendar.current.component(.hour, from: $0.date) % step == 0 }
    }
}
