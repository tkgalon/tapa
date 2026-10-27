import Foundation
import TapaCore

public struct JSONStateStore: StateStore {
    public static let currentSchemaVersion = 1
    public static let systemURL = URL(fileURLWithPath: "/Library/Application Support/Tapa/state.json")

    public enum LoadError: Error, Equatable {
        /// The file couldn't be decoded. It was moved to `quarantinedURL` so the next save doesn't
        /// overwrite it.
        case unreadable(quarantinedURL: URL)
        /// The file was written by a newer version of Tapa. It's left in place.
        case unsupportedSchemaVersion(Int)
    }

    private struct Header: Decodable {
        let schemaVersion: Int
    }

    private struct Envelope: Codable {
        let schemaVersion: Int
        let state: DaemonState
    }

    private let url: URL

    public init(url: URL = Self.systemURL) {
        self.url = url
    }

    public func load() throws -> DaemonState? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }

        let decoder = JSONDecoder()
        guard let version = try? decoder.decode(Header.self, from: data).schemaVersion else {
            throw quarantine()
        }
        guard version == Self.currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(version)
        }
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            throw quarantine()
        }
        return envelope.state
    }

    public func save(_ state: DaemonState) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(schemaVersion: Self.currentSchemaVersion, state: state))
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func quarantine() -> LoadError {
        let destination = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: url, to: destination)
        return .unreadable(quarantinedURL: destination)
    }
}
