import Foundation
import TapaCore

/// Blocks domains by mapping them to unroutable addresses in the hosts file.
public struct HostsFileEnforcer: BlockEnforcer {
    public static let systemHostsURL = URL(fileURLWithPath: "/etc/hosts")

    private let url: URL
    private let flushDNSCache: @Sendable () throws -> Void

    public init(
        url: URL = Self.systemHostsURL,
        flushDNSCache: @escaping @Sendable () throws -> Void = DNSCache.flush
    ) {
        self.url = url.resolvingSymlinksInPath()
        self.flushDNSCache = flushDNSCache
    }

    @discardableResult
    public func enforce(blocking domains: Set<DomainName>) throws -> Bool {
        let current = try String(contentsOf: url, encoding: .utf8)
        let desired = HostsFile(contents: current).rendered(blocking: domains)
        guard desired != current else { return false }

        try write(desired)
        try flushDNSCache()
        return true
    }

    private func write(_ contents: String) throws {
        let fileManager = FileManager.default
        let ownership = try fileManager.attributesOfItem(atPath: url.path)
            .filter { [.posixPermissions, .ownerAccountID, .groupOwnerAccountID].contains($0.key) }
        try Data(contents.utf8).write(to: url, options: .atomic)
        // An atomic write replaces the file, so its owner and mode have to be put back.
        try fileManager.setAttributes(ownership, ofItemAtPath: url.path)
    }
}
