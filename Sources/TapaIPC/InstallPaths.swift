import Foundation

/// Where the installer puts things that clients need to find.
public enum InstallPaths {
    /// The code signing requirement the daemon must meet, written by the installer because the
    /// certificate hash differs on every machine.
    public static let daemonRequirement = URL(fileURLWithPath: "/Library/Application Support/Tapa/daemon.requirement")

    public static func readDaemonRequirement() throws -> String {
        try String(contentsOf: daemonRequirement, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
