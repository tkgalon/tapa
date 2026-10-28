import Foundation

/// Whether the tracker may drive each installed browser, as it last found out. The permission
/// belongs to the tracker, so it writes this and Settings reads it.
public struct BrowserAccess: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case allowed
        case denied
        /// macOS will ask the first time a blocked site is opened in that browser.
        case notAsked
        /// The browser hasn't been open since the tracker started, so it couldn't be checked.
        case unknown
    }

    public var statuses: [String: Status]

    public init(statuses: [String: Status] = [:]) {
        self.statuses = statuses
    }

    /// `~/Library/Application Support/Tapa/browsers.json`.
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Tapa/browsers.json")
    }

    public static func read(from url: URL = defaultURL) -> BrowserAccess? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BrowserAccess.self, from: data)
    }

    public func write(to url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
