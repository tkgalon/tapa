import Foundation

public struct DomainName: Hashable, Sendable, CustomStringConvertible {
    /// The hosts file has no wildcards, so these subdomains are written out for every domain.
    public static let commonSubdomains = ["www", "m", "old", "mobile"]

    public let value: String

    /// Accepts full URLs and `*.` wildcards, ignores case, ports and trailing dots, and strips a
    /// leading `www.`. Returns `nil` for input that isn't a valid domain.
    public init?(_ raw: String) {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = host.range(of: "://") {
            host = String(host[scheme.upperBound...])
        }
        if let pathStart = host.firstIndex(where: { "/?#".contains($0) }) {
            host = String(host[..<pathStart])
        }
        if let userInfoEnd = host.lastIndex(of: "@") {
            host = String(host[host.index(after: userInfoEnd)...])
        }
        if let portStart = host.firstIndex(of: ":") {
            host = String(host[..<portStart])
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        if host.hasPrefix("*.") {
            host.removeFirst(2)
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy(Self.isValidLabel) else { return nil }
        value = host
    }

    public var description: String { value }

    public var hostsEntries: [String] {
        [value] + Self.commonSubdomains.map { "\($0).\(value)" }
    }

    /// Returns whether `host` is this domain or one of its subdomains.
    public func matches(host: String) -> Bool {
        var host = host.lowercased()
        while host.hasSuffix(".") {
            host.removeLast()
        }
        return host == value || host.hasSuffix("." + value)
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.count), label.first != "-", label.last != "-" else { return false }
        return label.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" }
    }
}

extension DomainName: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let domain = DomainName(raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid domain: \(raw)")
            )
        }
        self = domain
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct LeaveBehindList: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var domains: [DomainName]
    public var appBundleIDs: [String]

    public init(id: UUID = UUID(), name: String, domains: [DomainName], appBundleIDs: [String] = []) {
        self.id = id
        self.name = name
        self.domains = domains
        self.appBundleIDs = appBundleIDs
    }
}

public enum LeaveBehindGuard {
    /// Throws `TapaError.leaveBehindLocked` if a locked list loses a domain or app, or is removed.
    public static func validate(
        old: [LeaveBehindList],
        new: [LeaveBehindList],
        locked: Set<LeaveBehindList.ID>
    ) throws(TapaError) {
        let newByID = Dictionary(new.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for list in old where locked.contains(list.id) {
            guard let updated = newByID[list.id],
                  Set(list.domains).isSubset(of: updated.domains),
                  Set(list.appBundleIDs).isSubset(of: updated.appBundleIDs)
            else { throw .leaveBehindLocked }
        }
    }
}
