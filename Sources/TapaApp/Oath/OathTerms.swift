import SwiftUI
import TapaCore

/// Ends, Leave Behind and Rest Stops, each with its icon.
struct OathTerms: View {
    let request: StartRequest
    let websiteCount: Int

    var body: some View {
        VStack(spacing: 0) {
            OathTermRow(title: "Ends", systemImage: "clock") {
                TimelineView(.everyMinute) { context in
                    Text("\(request.endAt, format: .dateTime.hour().minute()) · in \(remaining(at: context.date))")
                        .monospacedDigit()
                }
            }
            Divider()
            OathTermRow(title: "Leave Behind", systemImage: "nosign") {
                Text("^[\(websiteCount) website](inflect: true)")
            }
            Divider()
            OathTermRow(title: "Rest Stops", systemImage: "cup.and.saucer") {
                Text("Off")
            }
        }
        .padding(.horizontal, 12)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
    }

    private func remaining(at now: Date) -> String {
        Duration.seconds(max(request.endAt.timeIntervalSince(now), 0))
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
