import AppKit
import SwiftUI
import TapaUsage

/// The installed browsers Mist works in, and whether Tapa may send their tabs there. The tracker
/// holds that permission, so it checks and writes it down, and this reads what it wrote.
struct BrowsersSection: View {
    private static let refreshInterval = Duration.seconds(30)
    private static let automationSettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    )

    @State private var browsers: [InstalledBrowser] = []

    var body: some View {
        Section {
            if browsers.isEmpty {
                Text("No supported browser found yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(browsers) { browser in
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(browser.statusText)
                            .foregroundStyle(
                                browser.status == .denied ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary)
                            )
                        if browser.status == .denied, let url = Self.automationSettings {
                            Button("Open Settings…") { NSWorkspace.shared.open(url) }
                        }
                    }
                } label: {
                    Label {
                        Text(browser.name)
                    } icon: {
                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                }
            }
        } header: {
            Text("Browsers")
        } footer: {
            Text("""
                Mist shows in Safari, Chrome, Arc, Brave, Edge and Opera. In other browsers, like Firefox, \
                what you left behind is still blocked, without Mist.
                """)
                .foregroundStyle(.secondary)
        }
        .task {
            while !Task.isCancelled {
                browsers = InstalledBrowser.all()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }
}

private struct InstalledBrowser: Identifiable {
    let id: String
    let name: String
    let icon: NSImage
    let status: BrowserAccess.Status

    var statusText: LocalizedStringKey {
        switch status {
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        case .notAsked: "Asks on first use"
        case .unknown: "Open it once to check"
        }
    }

    /// The browsers the tracker found installed, by name.
    static func all() -> [InstalledBrowser] {
        let statuses = BrowserAccess.read()?.statuses ?? [:]
        return statuses.compactMap { id, status in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
            let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
            return InstalledBrowser(id: id, name: name, icon: icon, status: status)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
