import Foundation
import os
import TapaCore
import TapaIPC

/// What the daemon is blocking right now, read every few seconds. Nothing is blocked at Basecamp
/// or during a Rest Stop, so tabs are left alone then.
@MainActor
final class BlockWatcher {
    private static let interval = Duration.seconds(5)
    private static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private(set) var snapshot: SessionSnapshot?
    private(set) var blocked: Set<DomainName> = []

    private let client: DaemonClient?

    init() {
        if let requirement = try? InstallPaths.readDaemonRequirement() {
            client = DaemonClient(daemonRequirement: requirement)
        } else {
            Self.logger.error("Tapa isn't installed, so nothing will be sent to Mist")
            client = nil
        }
    }

    func run() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: Self.interval)
        }
    }

    func refresh() async {
        guard let client else { return }
        do {
            let snapshot = try await client.status()
            let config = try await client.config()
            self.snapshot = snapshot
            blocked = snapshot.state == .ascent
                ? EffectivePolicy(activeSessions: snapshot.activeSessions).blockedDomains(in: config.leaveBehindLists)
                : []
        } catch {
            // Keep the last known rules. The daemon's hosts block still holds if this is stale.
            Self.logger.error("Reading the daemon failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The blocked domain that `host` falls under, if any.
    func domain(covering host: String) -> DomainName? {
        blocked.first { $0.matches(host: host) }
    }
}
