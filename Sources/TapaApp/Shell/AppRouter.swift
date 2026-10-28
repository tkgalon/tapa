import Foundation
import Observation
import TapaCore

/// What the main window shows, shared with the menu bar so that a menu item can bring up a screen
/// or a sheet there. The Oath and the Descent always run in the window, never in a menu.
@MainActor
@Observable
final class AppRouter {
    var selection: SidebarItem? = .basecamp
    var pendingOath: PendingOath?
    var isShowingDescent = false
    /// Set by Choose Time… so Basecamp opens its end times. Basecamp clears it once they show.
    var isChoosingEndTime = false
    var failure: String?
    var isShowingFailure = false

    func takeOath(for request: StartRequest) {
        selection = .basecamp
        pendingOath = PendingOath(request: request)
    }

    func showDescent() {
        selection = .basecamp
        isShowingDescent = true
    }

    /// A tapa:// link, opened by the tracker from Mist. Any website could open one too, so it only
    /// shows the Ascent and never acts.
    func open(_ url: URL) {
        guard url.scheme == "tapa" else { return }
        selection = .basecamp
    }

    func report(_ error: any Error) {
        failure = errorMessage(for: error)
        isShowingFailure = true
    }
}
