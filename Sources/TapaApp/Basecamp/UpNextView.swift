import SwiftUI

struct UpNextView: View {
    let upcoming: UpcomingRitual?
    let now: Date
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            if let upcoming {
                Text("⛺️ Basecamp · Up Next \(upcoming.interval.start.ritualStart(from: now))")
                    .font(.system(size: 13 * scale, weight: .semibold))
                Text(upcoming.ritual.name)
                    .font(.system(size: 40 * scale, weight: .semibold, design: .serif))
                Text(countdown(to: upcoming.interval.start))
                    .font(.system(size: 64 * scale, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("⛺️ Basecamp")
                    .font(.system(size: 13 * scale, weight: .semibold))
                Text("Ready when you are")
                    .font(.system(size: 40 * scale, weight: .semibold, design: .serif))
            }
        }
        .foregroundStyle(.white)
        .shadow(color: Color(red: 0.02, green: 0.08, blue: 0.19).opacity(0.45), radius: 8, y: 1)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func countdown(to start: Date) -> String {
        let remaining = Duration.seconds(max(start.timeIntervalSince(now), 60))
        return remaining.formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }
}
