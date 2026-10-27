import Foundation

public enum DNSCache {
    public struct CommandFailed: Error, Equatable {
        public let executable: String
        public let status: Int32
    }

    /// Clears the system DNS caches so hosts file changes apply at once. Requires root, since
    /// mDNSResponder ignores signals from other users.
    @Sendable
    public static func flush() throws {
        try run("/usr/bin/dscacheutil", "-flushcache")
        try run("/usr/bin/killall", "-HUP", "mDNSResponder")
    }

    private static func run(_ executable: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CommandFailed(executable: executable, status: process.terminationStatus)
        }
    }
}
