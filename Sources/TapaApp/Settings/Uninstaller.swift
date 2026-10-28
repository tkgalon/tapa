import AppKit
import ServiceManagement

/// Removes Tapa the way scripts/uninstall.sh does, with the administrator password asked for by
/// macOS, then removes the app itself.
enum Uninstaller {
    enum Failure: LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: String(localized: "Uninstalling was cancelled.")
            case .failed(let message): message
            }
        }
    }

    /// Matches the paths scripts/install.sh writes.
    private static let label = "id.tapa.daemon"
    private static let certificateName = "Tapa Local Signing"

    @MainActor
    static func run() throws(Failure) {
        let daemon = "/Library/PrivilegedHelperTools/\(label)"
        let commands = [
            "launchctl bootout system/\(label) 2>/dev/null || true",
            // The daemon is stopped now, so nothing rewrites the block after it's removed.
            "if [ -x \(daemon) ]; then \(daemon) --clear-hosts; fi",
            "rm -f /Library/LaunchDaemons/\(label).plist \(daemon) /usr/local/bin/tapactl",
            "rm -rf '/Library/Application Support/Tapa' /Library/Logs/Tapa",
            "rm -rf \(shellQuoted(Bundle.main.bundlePath))",
        ]
        try runAsAdministrator(commands.joined(separator: "; "))

        try? SMAppService.mainApp.unregister()
        let security = Process()
        security.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        security.arguments = ["delete-identity", "-c", certificateName]
        try? security.run()
        security.waitUntilExit()
    }

    @MainActor
    private static func runAsAdministrator(_ command: String) throws(Failure) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return }
        // -128 is the user cancelling the password prompt.
        if error[NSAppleScript.errorNumber] as? Int == -128 {
            throw .cancelled
        }
        throw .failed(error[NSAppleScript.errorMessage] as? String ?? String(localized: "Uninstalling failed."))
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
