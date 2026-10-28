import AppKit
import Foundation
import Network
import os
import TapaCore

/// Serves Mist on 127.0.0.1, so nothing outside this Mac can reach it. It only shows a page and
/// says whether a site is still blocked: actions go through tapa://, which asks in the app first.
@MainActor
final class MistServer {
    /// Tried in order, in case another app already holds the first.
    private static let ports: [UInt16] = Array(47800...47809)
    private nonisolated static let logger = Logger(subsystem: "id.tapa", category: "tracker")

    private let blocks: BlockWatcher
    /// Put in every Mist page and required to open Tapa. Other websites can send requests to
    /// 127.0.0.1 but can't read a Mist page, so they never learn it.
    private let openToken = UUID().uuidString
    private var listener: NWListener?
    private(set) var port: UInt16?

    init(blocks: BlockWatcher) {
        self.blocks = blocks
    }

    func start() {
        for candidate in Self.ports {
            guard let port = NWEndpoint.Port(rawValue: candidate) else { continue }
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
            guard let listener = try? NWListener(using: parameters) else { continue }
            listener.newConnectionHandler = { connection in
                Task { @MainActor in self.answer(connection) }
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    Self.logger.error("Mist server stopped: \(String(describing: error), privacy: .public)")
                }
            }
            listener.start(queue: .main)
            self.listener = listener
            self.port = candidate
            Self.logger.notice("Mist is served on port \(candidate)")
            return
        }
        Self.logger.error("No port was free for Mist")
    }

    /// Where a tab on `domain` goes instead. `from` is the tab's address, to return to once the
    /// site is no longer blocked.
    func address(for domain: DomainName, from: String) -> String? {
        guard let port else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)
        components.path = "/mist"
        components.queryItems = [
            URLQueryItem(name: "site", value: domain.value),
            URLQueryItem(name: "from", value: from),
        ]
        return components.string
    }

    private func answer(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            Task { @MainActor in
                let response = await self.response(to: data.flatMap { String(data: $0, encoding: .utf8) })
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private func response(to request: String?) async -> Data {
        // The request line reads "GET /mist?site=… HTTP/1.1".
        let requestLine = request?.split(separator: "\r\n").first?.split(separator: " ") ?? []
        let method = requestLine.first.map(String.init)
        guard requestLine.count > 1, let components = URLComponents(string: String(requestLine[1])) else {
            return Self.reply(status: "400 Bad Request", type: "text/plain", body: "")
        }
        let query = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        let site = query["site"].flatMap(DomainName.init)

        switch components.path {
        case "/mist":
            guard let site else { return Self.reply(status: "400 Bad Request", type: "text/plain", body: "") }
            let page = MistPage(
                site: site,
                returnAddress: Self.returnAddress(query["from"], on: site),
                snapshot: blocks.snapshot,
                photo: MistPage.photos.randomElement() ?? MistPage.photos[0],
                openToken: openToken
            )
            return Self.reply(status: "200 OK", type: "text/html; charset=utf-8", body: page.html)
        case let path where path.hasPrefix("/photo/"):
            return Self.photo(named: String(path.dropFirst("/photo/".count).dropLast(".jpg".count)))
        case "/open":
            guard method == "POST", query["token"] == openToken else {
                return Self.reply(status: "403 Forbidden", type: "text/plain", body: "")
            }
            Self.openTapa()
            return Self.reply(status: "204 No Content", type: "text/plain", body: "")
        case "/status":
            await blocks.refresh()
            let isBlocked = site.map { blocks.domain(covering: $0.value) != nil } ?? false
            return Self.reply(status: "200 OK", type: "application/json", body: "{\"blocked\":\(isBlocked)}")
        default:
            return Self.reply(status: "404 Not Found", type: "text/plain", body: "")
        }
    }

    /// Only an http or https address on the blocked site, so a crafted Mist link can't send the tab
    /// somewhere else.
    private static func returnAddress(_ raw: String?, on site: DomainName) -> String? {
        guard let raw, let url = URL(string: raw), ["http", "https"].contains(url.scheme ?? ""),
              let host = url.host(), site.matches(host: host)
        else { return nil }
        return url.absoluteString
    }

    /// Opens Tapa on its Ascent through Launch Services, so no browser asks first.
    private static func openTapa() {
        guard let url = URL(string: "tapa://open") else { return }
        NSWorkspace.shared.open(url)
    }

    /// One of the bundled Mist photos. Only the known names, so no other file can be read.
    private static func photo(named name: String) -> Data {
        guard MistPage.photos.contains(name),
              let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let data = try? Data(contentsOf: url)
        else { return reply(status: "404 Not Found", type: "text/plain", body: "") }
        return reply(status: "200 OK", type: "image/jpeg", data: data, cache: "max-age=86400")
    }

    private static func reply(status: String, type: String, body: String) -> Data {
        reply(status: status, type: type, data: Data(body.utf8), cache: "no-store")
    }

    private static func reply(status: String, type: String, data: Data, cache: String) -> Data {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\n"
            + "Cache-Control: \(cache)\r\nX-Frame-Options: DENY\r\nConnection: close\r\n\r\n"
        return Data(head.utf8) + data
    }
}
