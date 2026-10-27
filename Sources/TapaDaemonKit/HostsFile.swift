import TapaCore

/// A hosts file split into the user's own lines and the block Tapa manages between
/// `# TAPA BEGIN` and `# TAPA END`.
struct HostsFile {
    static let beginMarker = "# TAPA BEGIN"
    static let endMarker = "# TAPA END"

    private let original: String
    private let userLines: [String]
    private let hasTapaMarkers: Bool

    init(contents: String) {
        original = contents

        var kept: [String] = []
        var openBlock: [String]?
        var sawMarker = false
        for line in contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            switch line.trimmingCharacters(in: .whitespaces) {
            case Self.beginMarker:
                sawMarker = true
                openBlock = []
            case Self.endMarker:
                sawMarker = true
                openBlock = nil
            default:
                if openBlock != nil {
                    openBlock?.append(line)
                } else {
                    kept.append(line)
                }
            }
        }
        // Without an end marker, only lines Tapa could have written are dropped, so a damaged block
        // never swallows the user's own entries.
        if let unterminated = openBlock {
            kept += unterminated.filter { !Self.isTapaEntry($0) }
        }
        while kept.last?.isEmpty == true {
            kept.removeLast()
        }

        userLines = kept
        hasTapaMarkers = sawMarker
    }

    /// Returns the file with the Tapa block replaced by one blocking `domains`, or removed when
    /// `domains` is empty. A file without a Tapa block is returned unchanged when nothing is blocked.
    func rendered(blocking domains: Set<DomainName>) -> String {
        if domains.isEmpty, !hasTapaMarkers {
            return original
        }

        var lines = userLines
        if !domains.isEmpty {
            if lines.last?.isEmpty == false {
                lines.append("")
            }
            lines.append(Self.beginMarker)
            for host in domains.sorted(by: { $0.value < $1.value }).flatMap(\.hostsEntries) {
                lines.append("0.0.0.0 \(host)")
                lines.append(":: \(host)")
            }
            lines.append(Self.endMarker)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func isTapaEntry(_ line: String) -> Bool {
        let fields = line.split(whereSeparator: \.isWhitespace)
        return fields.count == 2 && (fields[0] == "0.0.0.0" || fields[0] == "::")
    }
}
