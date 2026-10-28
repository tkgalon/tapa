import SwiftUI
import TapaCore

/// The lengths to choose from once a Rest Stop's wait is over.
struct RestStopMenu: View {
    let take: (TimeInterval) -> Void

    var body: some View {
        Menu("☕️ Choose a Rest Stop") {
            Section("How long?") {
                ForEach(Self.minutes, id: \.self) { minutes in
                    Button(Duration.seconds(minutes * 60).formatted(.units(allowed: [.minutes], width: .wide))) {
                        take(TimeInterval(minutes * 60))
                    }
                }
            }
        }
    }

    private static let minutes = [1, 3, 5, 10, 15]
}

/// Where the Rest Stop stands: not asked for, waiting, ready to take, or open.
enum RestStopPhase: Equatable {
    case closed
    case waiting(until: Date)
    case ready
    case open
}

extension SessionSnapshot {
    func restStopPhase(at now: Date) -> RestStopPhase {
        if state == .restStop {
            return .open
        }
        if let readyAt = restStopReadyAt {
            if now < readyAt {
                return .waiting(until: readyAt)
            }
            if now < readyAt + AscentStateMachine.restStopReadyWindow {
                return .ready
            }
        }
        return .closed
    }

    /// The wait before the next Rest Stop can be taken.
    var restStopWait: TimeInterval {
        nextRestStopWait ?? AscentStateMachine.restStopWaits[0]
    }
}
