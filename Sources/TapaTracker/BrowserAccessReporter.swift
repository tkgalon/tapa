import AppKit
import CoreServices
import os
import TapaUsage

/// Checks, without asking, whether the tracker may drive each installed browser, and writes it down
/// for Settings. A browser that isn't open can't be checked, so its last known answer stays.
@MainActor
final class BrowserAccessReporter {
    private static let interval: TimeInterval = 30
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private var access = BrowserAccess.read() ?? BrowserAccess()
    private var timer: Timer?

    func start() {
        report()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.report() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func report() {
        var updated = BrowserAccess()
        for browser in Browser.allCases
        where NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.rawValue) != nil {
            updated.statuses[browser.rawValue] = Self.status(of: browser)
                ?? access.statuses[browser.rawValue]
                ?? .unknown
        }
        guard updated != access else { return }
        access = updated
        do {
            try access.write()
        } catch {
            Self.logger.error("Writing browser access failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// `nil` while the browser isn't running, since macOS can only answer for a running app.
    private static func status(of browser: Browser) -> BrowserAccess.Status? {
        var target = AEAddressDesc()
        let result: OSStatus = browser.rawValue.withCString { id in
            guard AECreateDesc(typeApplicationBundleID, id, strlen(id), &target) == noErr else {
                return OSStatus(paramErr)
            }
            defer { AEDisposeDesc(&target) }
            return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, false)
        }
        switch Int(result) {
        case Int(noErr): return .allowed
        case Int(errAEEventNotPermitted): return .denied
        case Int(errAEEventWouldRequireUserConsent): return .notAsked
        default: return nil
        }
    }
}
