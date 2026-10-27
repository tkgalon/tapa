import Foundation
import TapaCore
@testable import TapaDaemonKit
import Testing

final class FlushCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var calls: Int { lock.withLock { value } }

    func increment() {
        lock.withLock { value += 1 }
    }
}

/// Runs against a temporary copy, never the real `/etc/hosts`.
final class HostsFileEnforcerTests {
    let directory: URL
    let hosts: URL
    let flushes = FlushCounter()
    let enforcer: HostsFileEnforcer
    let original = "127.0.0.1\tlocalhost\n::1             localhost\n"
    let reddit = DomainName("reddit.com")!

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        hosts = directory.appendingPathComponent("hosts")
        try Data(original.utf8).write(to: hosts)
        let flushes = flushes
        enforcer = HostsFileEnforcer(url: hosts, flushDNSCache: { flushes.increment() })
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func contents() throws -> String {
        try String(contentsOf: hosts, encoding: .utf8)
    }

    @Test func blocksAndFlushesOnce() throws {
        #expect(try enforcer.enforce(blocking: [reddit]))
        #expect(try contents().contains("0.0.0.0 reddit.com"))
        #expect(flushes.calls == 1)
    }

    @Test func doesNothingWhenAlreadyInPlace() throws {
        try enforcer.enforce(blocking: [reddit])
        #expect(try !enforcer.enforce(blocking: [reddit]))
        #expect(flushes.calls == 1)
    }

    @Test func restoresTheBlockAfterManualEdits() throws {
        try enforcer.enforce(blocking: [reddit])
        try Data(original.utf8).write(to: hosts)

        #expect(try enforcer.enforce(blocking: [reddit]))
        #expect(try contents().contains("0.0.0.0 reddit.com"))
    }

    @Test func unblockingRestoresTheOriginalFile() throws {
        try enforcer.enforce(blocking: [reddit])
        try enforcer.enforce(blocking: [])
        #expect(try contents() == original)
    }

    @Test func keepsFilePermissions() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: hosts.path)
        try enforcer.enforce(blocking: [reddit])
        let permissions = try FileManager.default.attributesOfItem(atPath: hosts.path)[.posixPermissions] as? Int
        #expect(permissions == 0o640)
    }

    @Test func missingFileThrowsWithoutFlushing() throws {
        try FileManager.default.removeItem(at: hosts)
        #expect(throws: (any Error).self) { try self.enforcer.enforce(blocking: [self.reddit]) }
        #expect(flushes.calls == 0)
    }
}
