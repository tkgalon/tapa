import AppKit
import LinkPresentation
import Observation
import TapaCore

/// Site icons for Leave Behind, fetched once from each site and cached on disk. A site that's
/// blocked or offline has no icon until a later fetch succeeds.
@MainActor
@Observable
final class FaviconStore {
    private nonisolated static let fetchTimeout: TimeInterval = 10

    private(set) var icons: [String: NSImage] = [:]
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private let directory = URL.applicationSupportDirectory.appending(path: "Tapa/Favicons")

    func icon(for domain: DomainName) -> NSImage? {
        icons[domain.value]
    }

    func load(_ domain: DomainName) async {
        let host = domain.value
        guard icons[host] == nil, !inFlight.contains(host) else { return }
        inFlight.insert(host)
        defer { inFlight.remove(host) }

        let file = directory.appending(path: host)
        if let data = try? Data(contentsOf: file), let image = NSImage(data: data) {
            icons[host] = image
            return
        }
        guard let data = await Self.fetchIcon(host: host), let image = NSImage(data: data) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file)
        icons[host] = image
    }

    private nonisolated static func fetchIcon(host: String) async -> Data? {
        guard let url = URL(string: "https://\(host)") else { return nil }
        let provider = LPMetadataProvider()
        provider.timeout = fetchTimeout
        guard let metadata = try? await provider.startFetchingMetadata(for: url),
              let iconProvider = metadata.iconProvider
        else { return nil }
        return await withCheckedContinuation { continuation in
            _ = iconProvider.loadDataRepresentation(for: .image) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
