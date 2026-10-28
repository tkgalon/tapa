import Foundation
import SQLite3

/// Seconds spent in each app and site, summed per minute, and the times a Leave Behind site was
/// sent to Mist. The tracker writes it. The app only reads.
public final class UsageDatabase {
    public enum Failure: Error, Equatable {
        case open(String)
        case statement(String)
    }

    /// `~/Library/Application Support/Tapa/usage.sqlite`, as the PRD lays out.
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Tapa/usage.sqlite")
    }

    private var handle: OpaquePointer?

    /// Opens the file, creating it and its tables unless `readOnly`.
    public init(url: URL = UsageDatabase.defaultURL, readOnly: Bool = false) throws {
        if !readOnly {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        guard sqlite3_open_v2(url.path(percentEncoded: false), &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw Failure.open(message)
        }
        // The tracker writes while the app reads, so readers wait briefly instead of failing.
        sqlite3_busy_timeout(handle, 1000)
        if !readOnly {
            try execute("PRAGMA journal_mode = WAL")
            try execute("""
                CREATE TABLE IF NOT EXISTS usage (
                    minute INTEGER NOT NULL,
                    app TEXT NOT NULL,
                    domain TEXT NOT NULL,
                    focused INTEGER NOT NULL,
                    seconds INTEGER NOT NULL,
                    PRIMARY KEY (minute, app, domain, focused)
                )
                """)
            try execute("CREATE TABLE IF NOT EXISTS attempts (at INTEGER NOT NULL, domain TEXT NOT NULL)")
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Adds each entry's seconds to its minute, so writing a minute twice sums rather than replaces.
    public func record(_ entries: [UsageEntry]) throws {
        try execute("BEGIN")
        do {
            for entry in entries {
                try execute(
                    """
                    INSERT INTO usage (minute, app, domain, focused, seconds) VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT (minute, app, domain, focused) DO UPDATE SET seconds = seconds + excluded.seconds
                    """,
                    bind: [
                        .integer(Int64(entry.minute.timeIntervalSince1970)),
                        .text(entry.app),
                        .text(entry.domain ?? ""),
                        .integer(entry.isFocused ? 1 : 0),
                        .integer(Int64(entry.seconds)),
                    ]
                )
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// A Leave Behind site the tracker sent to Mist.
    public func recordAttempt(on domain: String, at date: Date) throws {
        try execute(
            "INSERT INTO attempts (at, domain) VALUES (?, ?)",
            bind: [.integer(Int64(date.timeIntervalSince1970)), .text(domain)]
        )
    }

    /// Screen time and focused time from `start` on.
    public func totals(since start: Date) throws -> UsageTotals {
        let sql = "SELECT COALESCE(SUM(seconds), 0), COALESCE(SUM(seconds * focused), 0) FROM usage WHERE minute >= ?"
        var statement: OpaquePointer?
        try prepare(sql, into: &statement)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_ROW else { return UsageTotals(screenTime: 0, focused: 0) }
        return UsageTotals(
            screenTime: TimeInterval(sqlite3_column_int64(statement, 0)),
            focused: TimeInterval(sqlite3_column_int64(statement, 1))
        )
    }

    /// How many times a Leave Behind site was sent to Mist from `start` on.
    public func attempts(since start: Date) throws -> Int {
        var statement: OpaquePointer?
        try prepare("SELECT COUNT(*) FROM attempts WHERE at >= ?", into: &statement)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    // MARK: SQLite

    private enum Value {
        case integer(Int64)
        case text(String)
    }

    private func execute(_ sql: String, bind values: [Value] = []) throws {
        var statement: OpaquePointer?
        try prepare(sql, into: &statement)
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .integer(let number):
                sqlite3_bind_int64(statement, position, number)
            case .text(let text):
                sqlite3_bind_text(statement, position, text, -1, Self.transient)
            }
        }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw Failure.statement(String(cString: sqlite3_errmsg(handle)))
        }
    }

    private func prepare(_ sql: String, into statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Failure.statement(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Tells SQLite to copy bound text, since Swift strings don't outlive the call.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

public struct UsageTotals: Equatable, Sendable {
    public let screenTime: TimeInterval
    public let focused: TimeInterval

    public init(screenTime: TimeInterval, focused: TimeInterval) {
        self.screenTime = screenTime
        self.focused = focused
    }
}
