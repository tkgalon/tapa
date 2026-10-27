import Foundation
import TapaCore
@testable import TapaDaemonKit
import TapaIPC
import Testing

/// Runs the real XPC machinery in-process through an anonymous listener.
@Suite(.timeLimit(.minutes(1)))
final class DaemonXPCTests {
    let social = LeaveBehindList(name: "Social", domains: [DomainName("reddit.com")!])
    let enforcer = RecordingEnforcer()
    let engine: SessionEngine
    var servers: [DaemonXPCServer] = []

    init() {
        engine = SessionEngine(
            store: InMemoryStateStore(),
            enforcer: enforcer,
            monotonic: FakeMonotonicClock(),
            bootSessionID: "boot-1"
        )
    }

    func connect(clientRequirement: String? = nil, daemonRequirement: String? = nil) -> DaemonClient {
        let listener = NSXPCListener.anonymous()
        let server = DaemonXPCServer(listener: listener, engine: engine, clientRequirement: clientRequirement)
        server.resume()
        servers.append(server)
        return DaemonClient(endpoint: listener.endpoint, daemonRequirement: daemonRequirement)
    }

    @Test func reportsStatus() async throws {
        let snapshot = try await connect().status()
        #expect(snapshot.state == .basecamp)
    }

    @Test func appliesCommands() async throws {
        let client = connect()
        try await client.updateConfig(DaemonConfig(leaveBehindLists: [social]))
        #expect(try await client.config().leaveBehindLists == [social])

        let request = StartRequest(
            mode: .trail,
            endAt: Date().addingTimeInterval(3600),
            leaveBehindIDs: [social.id]
        )
        let snapshot = try await client.start(request)
        #expect(snapshot.state == .ascent)
        #expect(enforcer.blocked == Set(social.domains))
    }

    @Test func passesRefusalsThrough() async throws {
        let client = connect()
        let withoutOath = StartRequest(mode: .summit, endAt: Date().addingTimeInterval(3600), leaveBehindIDs: [UUID()])
        await #expect(throws: TapaError.oathRequired) {
            try await client.start(withoutOath)
        }
    }

    @Test func rejectsClientsThatDontMeetTheRequirement() async {
        let client = connect(clientRequirement: #"identifier "id.tapa.someone-else""#)
        await #expect(throws: DaemonClientError.unreachable) {
            try await client.status()
        }
    }

    @Test func clientsRejectAnUnexpectedDaemon() async {
        let client = connect(daemonRequirement: #"identifier "id.tapa.someone-else""#)
        await #expect(throws: DaemonClientError.unreachable) {
            try await client.status()
        }
    }

    @Test func answersOtherProtocolVersionsWithIncompatible() async throws {
        let message = try JSONEncoder().encode(RequestEnvelope(request: .status, version: 99))
        let reply = await DaemonXPCServer.Service.handle(message, engine: engine)
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: reply)
        #expect(envelope.response == .incompatible(daemonVersion: DaemonProtocol.version))
    }

    @Test func answersGarbageWithIncompatible() async throws {
        let reply = await DaemonXPCServer.Service.handle(Data("not json".utf8), engine: engine)
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: reply)
        #expect(envelope.response == .incompatible(daemonVersion: DaemonProtocol.version))
    }
}
