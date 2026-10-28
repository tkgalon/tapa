import Foundation
import TapaCore
import TapaIPC

/// A sentence for an alert, for errors the daemon or the connection to it can throw.
func errorMessage(for error: any Error) -> String {
    switch error {
    case let error as TapaError:
        message(for: error)
    case let error as DaemonClientError:
        message(for: error)
    default:
        error.localizedDescription
    }
}

private func message(for error: TapaError) -> String {
    switch error {
    case .invalidDuration: String(localized: "An Ascent lasts 15 minutes to 12 hours.")
    case .invalidSchedule: String(localized: "A Ritual needs at least one day and lasts 15 minutes to 12 hours.")
    case .emptyLeaveBehind: String(localized: "Choose at least one Leave Behind list.")
    case .oathRequired: String(localized: "Summit Mode starts only after The Summit Oath.")
    case .summitLocked: String(localized: "Summit Mode can end early only with a Descent.")
    case .notInAscent: String(localized: "No Ascent is running.")
    case .alreadyInRestStop: String(localized: "A Rest Stop is already running.")
    case .notInRestStop: String(localized: "The Rest Stop has already ended.")
    case .restStopNotReady: String(localized: "The Rest Stop isn't ready yet. Ask for one and wait.")
    case .sessionNotFound: String(localized: "That Ascent has already ended.")
    case .reasonRequired: String(localized: "Write what needs you right now.")
    case .noDescentLeft: String(localized: "No Descents are left this week.")
    case .noSummitActive: String(localized: "Summit Mode isn't running.")
    case .leaveBehindLocked: String(localized: "Websites can't be removed while Summit Mode is running.")
    }
}

private func message(for error: DaemonClientError) -> String {
    switch error {
    case .unreachable:
        String(localized: "Tapa's background service isn't responding.")
    case .incompatible:
        String(localized: "Tapa's background service is a different version. Reinstall Tapa to match.")
    case .unexpectedResponse:
        String(localized: "Tapa's background service sent a reply the app doesn't understand.")
    }
}
