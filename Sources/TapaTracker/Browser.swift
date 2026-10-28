import AppKit

/// A browser whose tab address the tracker can read and replace with Apple events. Safari calls
/// the tab in view `current tab`. The Chromium browsers call it `active tab`.
enum Browser: String, CaseIterable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case arc = "company.thebrowser.Browser"
    case brave = "com.brave.Browser"
    case edge = "com.microsoft.edgemac"
    case opera = "com.operasoftware.Opera"

    init?(_ application: NSRunningApplication) {
        guard let id = application.bundleIdentifier, let browser = Browser(rawValue: id) else { return nil }
        self = browser
    }

    private var tab: String {
        self == .safari ? "current tab" : "active tab"
    }

    var readAddress: String {
        "tell application id \"\(rawValue)\" to get URL of \(tab) of front window"
    }

    func replaceAddress(with address: String) -> String {
        "tell application id \"\(rawValue)\" to set URL of \(tab) of front window to \"\(address)\""
    }
}
