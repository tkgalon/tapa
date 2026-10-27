import Foundation
import TapaCore
@testable import TapaDaemonKit
import Testing

final class JSONStateStoreTests {
    let directory: URL
    let stateURL: URL
    let store: JSONStateStore
    let now = Date(timeIntervalSinceReferenceDate: 815_000_000.123)

    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        stateURL = directory.appendingPathComponent("Tapa/state.json")
        store = JSONStateStore(url: stateURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func sampleState() throws -> DaemonState {
        let ledger = DescentLedger(now: now, calendar: Calendar(identifier: .gregorian))
        var ascent = AscentStateMachine(descentLedger: ledger)
        _ = try ascent.start(
            StartRequest(mode: .summit, endAt: now.addingTimeInterval(3600), leaveBehindIDs: [UUID()], oathTaken: true),
            now: now
        )
        var clock = TrustedClock(bootSessionID: "boot-1", systemTime: now, monotonic: 42.5)
        clock.verify(networkTime: now, monotonic: 42.5)
        return DaemonState(ascent: ascent, clock: clock)
    }

    func write(_ json: String) throws {
        let parent = stateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: stateURL)
    }

    @Test func loadsNothingBeforeTheFirstSave() throws {
        #expect(try store.load() == nil)
    }

    @Test func roundTripsExactly() throws {
        let state = try sampleState()
        try store.save(state)
        #expect(try store.load() == state)
    }

    @Test func overwritesThePreviousState() throws {
        try store.save(try sampleState())
        let latest = try sampleState()
        try store.save(latest)
        #expect(try store.load() == latest)
    }

    @Test func writesAVersionedPrivateFile() throws {
        try store.save(try sampleState())

        let json = try String(contentsOf: stateURL, encoding: .utf8)
        #expect(json.contains(#""schemaVersion" : 1"#))

        let fileManager = FileManager.default
        let fileMode = try fileManager.attributesOfItem(atPath: stateURL.path)[.posixPermissions] as? Int
        let directoryPath = stateURL.deletingLastPathComponent().path
        let directoryMode = try fileManager.attributesOfItem(atPath: directoryPath)[.posixPermissions] as? Int
        #expect(fileMode == 0o600)
        #expect(directoryMode == 0o700)
    }

    @Test(arguments: ["not json", #"{"schemaVersion": 1, "state": {}}"#])
    func quarantinesAnUnreadableFile(json: String) throws {
        try write(json)
        let quarantined = stateURL.appendingPathExtension("corrupt")

        #expect(throws: JSONStateStore.LoadError.unreadable(quarantinedURL: quarantined)) { try self.store.load() }
        #expect(try String(contentsOf: quarantined, encoding: .utf8) == json)
        #expect(try store.load() == nil)
    }

    @Test func leavesANewerSchemaInPlace() throws {
        let json = #"{"schemaVersion": 2, "state": {}}"#
        try write(json)

        #expect(throws: JSONStateStore.LoadError.unsupportedSchemaVersion(2)) { try self.store.load() }
        #expect(try String(contentsOf: stateURL, encoding: .utf8) == json)
    }
}
