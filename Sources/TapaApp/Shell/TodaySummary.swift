import SwiftUI
import TapaUsage

/// Today's screen time and focus at the foot of the sidebar, as the tracker counted them. Shows
/// dashes until the tracker has written anything.
struct TodaySummary: View {
    private static let refreshInterval = Duration.seconds(60)

    @State private var totals: UsageTotals?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            row("Screen Time", value: totals?.screenTime)
            row("Focused", value: totals?.focused)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .task {
            while !Task.isCancelled {
                totals = Self.today()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, value: TimeInterval?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if let value {
                Text(Duration.seconds(value).formatted(.units(allowed: [.hours, .minutes], width: .narrow)))
                    .monospacedDigit()
            } else {
                Text(verbatim: "–")
                    .accessibilityLabel(Text("Not available yet"))
            }
        }
        .font(.callout)
    }

    private static func today() -> UsageTotals? {
        guard let database = try? UsageDatabase(readOnly: true) else { return nil }
        return try? database.totals(since: Calendar.current.startOfDay(for: .now))
    }
}
