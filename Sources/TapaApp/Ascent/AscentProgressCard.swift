import SwiftUI

/// How far along the Ascent is, what's left behind, and whether Rest Stops are open.
struct AscentProgressCard: View {
    let startAt: Date
    let endAt: Date
    let leaveBehind: Text
    let restStops: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 6) {
                    ProgressView(value: progress(at: context.date))
                        .tint(Color.glacier)
                    HStack {
                        Text("Started \(startAt, format: .dateTime.hour().minute())")
                        Spacer()
                        Text("Now \(context.date, format: .dateTime.hour().minute())")
                        Spacer()
                        Text("Ends \(endAt, format: .dateTime.hour().minute())")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            HStack(alignment: .top, spacing: 24) {
                fact(title: "Leave Behind", value: leaveBehind)
                fact(title: "Rest Stops", value: Text(restStops))
            }
        }
        .padding(16)
        .frame(width: 480)
        .glassBackground(in: .rect(cornerRadius: 16))
    }

    private func fact(title: LocalizedStringKey, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            value
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progress(at now: Date) -> Double {
        let total = endAt.timeIntervalSince(startAt)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(startAt) / total, 0), 1)
    }
}
