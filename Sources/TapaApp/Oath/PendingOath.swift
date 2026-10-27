import Foundation
import TapaCore

/// A Summit Mode request waiting for the user to take The Summit Oath.
struct PendingOath: Identifiable {
    let id = UUID()
    let request: StartRequest
}
