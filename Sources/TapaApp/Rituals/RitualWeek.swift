import SwiftUI
import TapaCore

/// The week as a calendar: a column per day, hours down the side, and a named block for each Ritual.
/// Rituals that overlap sit side by side. Each keeps the color of its place in the list.
struct RitualWeek: View {
    /// Every Ritual, in list order. Only the ones switched on appear.
    let rituals: [Ritual]
    let edit: (Ritual) -> Void

    /// Tall enough that an hour long Ritual still shows its name.
    private let hourHeight: CGFloat = 14
    private let gutterWidth: CGFloat = 36
    private let dayMinutes = 24 * 60
    /// The chart starts at 06.00 unless a Ritual runs earlier.
    private let usualFirstMinute = 6 * 60
    private let hourMarkStep = 3
    private let laneGap: CGFloat = 2

    var body: some View {
        let today = Weekday.today()
        let week = Weekday.week()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Color.clear.frame(width: gutterWidth, height: 1)
                ForEach(week, id: \.self) { day in
                    Text(day.shortName())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(day == today ? AnyShapeStyle(Color.glacier) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(alignment: .top, spacing: 4) {
                hourLabels
                ForEach(week, id: \.self) { day in
                    column(for: day, isToday: day == today)
                }
            }
            .frame(height: chartHeight)
            .background(alignment: .topLeading) { hourLines }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator)
        }
        .accessibilityElement()
        .accessibilityLabel("This week")
        .accessibilityValue(scheduled.map(\.ritual).map { "\($0.name), \($0.schedule())" }.joined(separator: ". "))
    }

    // MARK: Hours

    private var chartHeight: CGFloat {
        CGFloat(dayMinutes - firstMinute) / 60 * hourHeight
    }

    private var hourMarks: [Int] {
        let firstHour = firstMinute / 60
        let start = (firstHour + hourMarkStep - 1) / hourMarkStep * hourMarkStep
        return Array(stride(from: start, to: 24, by: hourMarkStep))
    }

    private var hourLabels: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(hourMarks, id: \.self) { hour in
                let lineY = y(forMinute: hour * 60)
                Text(TimeOfDay(hour: hour)?.formatted() ?? "")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .alignmentGuide(.top) { label in label.height / 2 - lineY }
            }
        }
        .frame(width: gutterWidth, height: chartHeight, alignment: .topTrailing)
    }

    private var hourLines: some View {
        ZStack(alignment: .topLeading) {
            ForEach(hourMarks, id: \.self) { hour in
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
                    .offset(y: y(forMinute: hour * 60))
            }
        }
        .padding(.leading, gutterWidth + 4)
        .frame(height: chartHeight, alignment: .top)
    }

    private func y(forMinute minute: Int) -> CGFloat {
        CGFloat(minute - firstMinute) / CGFloat(dayMinutes - firstMinute) * chartHeight
    }

    // MARK: Days

    private func column(for day: Weekday, isToday: Bool) -> some View {
        let segments = laidOut(segments(on: day))
        return RoundedRectangle(cornerRadius: 6)
            .fill(isToday ? AnyShapeStyle(Color.glacierTint.opacity(0.6)) : AnyShapeStyle(.clear))
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ForEach(segments) { placed in
                        // The gap sits only between lanes, so a lone block is centred in its day.
                        let lanes = CGFloat(placed.laneCount)
                        let laneWidth = (width - laneGap * (lanes - 1)) / lanes
                        let height = blockHeight(placed.segment)
                        block(placed.segment, width: laneWidth, height: height)
                            .offset(
                                x: (laneWidth + laneGap) * CGFloat(placed.lane),
                                y: y(forMinute: placed.segment.startMinute)
                            )
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
    }

    private func blockHeight(_ segment: Segment) -> CGFloat {
        max(y(forMinute: segment.endMinute) - y(forMinute: segment.startMinute) - 1, 6)
    }

    /// The name, then the times when there's room. The Summit Mode mark only where the name still fits
    /// beside it. Anything taller than the block is cut off at its edge.
    private func block(_ segment: Segment, width: CGFloat, height: CGFloat) -> some View {
        let ritual = segment.ritual
        return Button {
            edit(ritual)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    if ritual.mode == .summit, width >= 64 {
                        Image(systemName: "mountain.2.fill")
                            .imageScale(.small)
                    }
                    Text(ritual.name)
                }
                .font(.caption.weight(.semibold))
                if height >= 32 {
                    Text("\(ritual.startTime.formatted())–\(ritual.endTime.formatted())")
                        .font(.caption2)
                        .monospacedDigit()
                        .opacity(0.85)
                }
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.top, height >= 20 ? 4 : 1)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(segment.color)
            .clipShape(.rect(cornerRadius: 5))
            .contentShape(.rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("\(ritual.name), \(ritual.schedule())")
    }

    // MARK: Segments

    private var firstMinute: Int {
        let earliest = scheduled.flatMap(segments).map(\.startMinute).min() ?? usualFirstMinute
        return min(earliest / 60 * 60, usualFirstMinute)
    }

    private func segments(on day: Weekday) -> [Segment] {
        scheduled.flatMap(segments).filter { $0.day == day }
    }

    private var scheduled: [(ritual: Ritual, color: Color)] {
        rituals.enumerated()
            .filter { $0.element.enabled }
            .map { (ritual: $0.element, color: Color.ritual(at: $0.offset)) }
    }

    /// A Ritual that crosses midnight runs into the next morning.
    private func segments(of scheduled: (ritual: Ritual, color: Color)) -> [Segment] {
        let (ritual, color) = scheduled
        let start = ritual.startTime.minutesSinceMidnight
        let end = ritual.endTime.minutesSinceMidnight
        return ritual.days.flatMap { day in
            guard ritual.crossesMidnight else {
                return [Segment(ritual: ritual, color: color, day: day, startMinute: start, endMinute: end)]
            }
            var parts = [Segment(ritual: ritual, color: color, day: day, startMinute: start, endMinute: dayMinutes)]
            if end > 0 {
                parts.append(Segment(ritual: ritual, color: color, day: day.next, startMinute: 0, endMinute: end))
            }
            return parts
        }
    }

    /// Gives each segment the first lane free at its start, as a calendar does with overlapping events.
    /// Only segments that overlap, directly or through each other, share the width. A segment on its
    /// own keeps the whole day.
    private func laidOut(_ segments: [Segment]) -> [PlacedSegment] {
        var placed: [PlacedSegment] = []
        var cluster: [(segment: Segment, lane: Int)] = []
        var laneEnds: [Int] = []

        func closeCluster() {
            placed += cluster.map { PlacedSegment(segment: $0.segment, lane: $0.lane, laneCount: laneEnds.count) }
            cluster = []
            laneEnds = []
        }

        let sorted = segments.sorted { ($0.startMinute, $0.ritual.name) < ($1.startMinute, $1.ritual.name) }
        for segment in sorted {
            if let clusterEnd = laneEnds.max(), segment.startMinute >= clusterEnd {
                closeCluster()
            }
            if let free = laneEnds.firstIndex(where: { $0 <= segment.startMinute }) {
                laneEnds[free] = segment.endMinute
                cluster.append((segment, free))
            } else {
                laneEnds.append(segment.endMinute)
                cluster.append((segment, laneEnds.count - 1))
            }
        }
        closeCluster()
        return placed
    }
}

private struct Segment {
    let ritual: Ritual
    let color: Color
    let day: Weekday
    let startMinute: Int
    let endMinute: Int
}

private struct PlacedSegment: Identifiable {
    let segment: Segment
    let lane: Int
    let laneCount: Int

    var id: String { "\(segment.ritual.id)-\(segment.startMinute)" }
}
