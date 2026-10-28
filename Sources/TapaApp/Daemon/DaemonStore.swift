import Foundation
import Observation
import TapaCore
import TapaIPC

/// The app's view of the daemon. Polls its state and forwards the user's requests.
@MainActor
@Observable
final class DaemonStore {
    enum Connection: Equatable {
        case connecting
        case connected
        case notInstalled
        case unreachable
    }

    private static let pollInterval = Duration.seconds(5)

    private(set) var connection = Connection.connecting
    private(set) var snapshot: SessionSnapshot?
    private(set) var config = DaemonConfig()

    private var client: DaemonClient?

    /// Polls the daemon for as long as the calling task runs.
    func run() async {
        guard let requirement = try? InstallPaths.readDaemonRequirement() else {
            connection = .notInstalled
            return
        }
        client = DaemonClient(daemonRequirement: requirement)
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    func refresh() async {
        guard let client else { return }
        do {
            snapshot = try await client.status()
            config = try await client.config()
            connection = .connected
        } catch {
            connection = .unreachable
        }
    }

    func start(_ request: StartRequest) async throws {
        snapshot = try await connectedClient().start(request)
    }

    func endTrail(sessionID: UUID) async throws {
        snapshot = try await connectedClient().endTrail(sessionID: sessionID)
    }

    func useDescent(reason: String) async throws {
        snapshot = try await connectedClient().useDescent(reason: reason, scope: .summit)
    }

    func requestRestStop() async throws {
        snapshot = try await connectedClient().requestRestStop()
    }

    func startRestStop(length: TimeInterval) async throws {
        snapshot = try await connectedClient().startRestStop(length: length)
    }

    func endRestStop() async throws {
        snapshot = try await connectedClient().endRestStop()
    }

    func updateConfig(_ newConfig: DaemonConfig) async throws {
        snapshot = try await connectedClient().updateConfig(newConfig)
        config = newConfig
    }

    /// The enabled Ritual that starts soonest after `date`.
    func upNext(after date: Date, calendar: Calendar = .current) -> UpcomingRitual? {
        config.rituals
            .filter(\.enabled)
            .compactMap { ritual in
                ritual.nextOccurrence(after: date, calendar: calendar)
                    .map { UpcomingRitual(ritual: ritual, interval: $0) }
            }
            .min { $0.interval.start < $1.interval.start }
    }

    /// The Ritual that started the running Ascent, when one did.
    var runningRitualName: String? {
        for session in snapshot?.activeSessions ?? [] {
            if case .ritual(let id) = session.source {
                return config.rituals.first { $0.id == id }?.name
            }
        }
        return nil
    }

    /// The Leave Behind lists the running Ascent enforces, in list order.
    var activeLists: [LeaveBehindList] {
        let ids = Set(snapshot?.activeSessions.flatMap(\.leaveBehindIDs) ?? [])
        return config.leaveBehindLists.filter { ids.contains($0.id) }
    }

    /// Ends every Trail session. Summit Mode sessions stay, since only a Descent ends them.
    func endTrails() async throws {
        for session in snapshot?.activeSessions ?? [] where session.mode == .trail {
            try await endTrail(sessionID: session.id)
        }
    }

    private func connectedClient() throws -> DaemonClient {
        guard let client else { throw DaemonClientError.unreachable }
        return client
    }
}
