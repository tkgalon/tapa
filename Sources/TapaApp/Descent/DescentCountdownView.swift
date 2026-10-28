import SwiftUI

/// The last 30 seconds before Summit Mode ends, with a way back up the whole time.
struct DescentCountdownView: View {
    private static let length = 30

    let reason: String
    let stay: () -> Void
    let descend: () -> Void

    @State private var secondsLeft = Self.length

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(secondsLeft) / Double(Self.length))
                    .stroke(Color.summitNight, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: secondsLeft)
                Text(secondsLeft, format: .number)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: 128, height: 128)
            .accessibilityElement()
            .accessibilityLabel(Text("^[\(secondsLeft) second](inflect: true) left"))

            VStack(spacing: 4) {
                Text("Descending in ^[\(secondsLeft) Second](inflect: true)")
                    .font(.title3.bold())
                    .contentTransition(.numericText(countsDown: true))
                Text("Take a breath. If it can wait after all, you can still turn back.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Button("Stay on Your Path", action: stay)
                    .buttonStyle(.borderedProminent)
                    .tint(.glacier)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                Text("Summit Mode ends when the countdown finishes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            for _ in 0..<Self.length {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                withAnimation {
                    secondsLeft -= 1
                }
            }
            descend()
        }
    }
}
