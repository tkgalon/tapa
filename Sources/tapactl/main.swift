import Foundation
import TapaCore
import TapaIPC

// A developer tool for driving the daemon before the app exists.

let usage = """
    usage: tapactl <command>

      status
      lists
      add-list <name> <domain>...
      start trail|summit <minutes> <list name>... [--take-oath]
      end <session id>
      rest
      take-rest [minutes]
      end-rest
      descent <reason>
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func describe(_ snapshot: SessionSnapshot) {
    let time = Date.FormatStyle(date: .omitted, time: .shortened)
    print("State: \(snapshot.state.rawValue)")
    print("Mode: \(snapshot.mode?.rawValue ?? "none")")
    if let endsAt = snapshot.endsAt {
        print("Ends: \(endsAt.formatted(time))")
    }
    if let readyAt = snapshot.restStopReadyAt {
        print("Rest Stop ready at: \(readyAt.formatted(.dateTime.hour().minute().second()))")
    }
    if let restStop = snapshot.restStop {
        print("Rest Stop until: \(restStop.endAt.formatted(time))")
    }
    for session in snapshot.activeSessions {
        print("Session \(session.id.uuidString): \(session.mode.rawValue) until \(session.endAt.formatted(time))")
    }
    print("Descents left this week: \(snapshot.descentsRemaining)")
    print("Clock verified: \(snapshot.isClockVerified ? "yes" : "no")")
    if snapshot.recoveredFromUnreadableState {
        print("Warning: saved state was unreadable, so the daemon started over at Basecamp.")
    }
}

func listIDs(named names: some Sequence<String>, in config: DaemonConfig) -> Set<UUID> {
    Set(names.map { name in
        guard let list = config.leaveBehindLists.first(where: { $0.name == name }) else {
            fail("No Leave Behind list named \(name). See `tapactl lists`.")
        }
        return list.id
    })
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail(usage) }
let options = Array(arguments.dropFirst())

let requirement: String
do {
    requirement = try InstallPaths.readDaemonRequirement()
} catch {
    fail("Tapa isn't installed. Run scripts/install.sh first.")
}
let client = DaemonClient(daemonRequirement: requirement)

do {
    switch command {
    case "status":
        describe(try await client.status())

    case "lists":
        for list in try await client.config().leaveBehindLists {
            print("\(list.name): \(list.domains.map(\.value).joined(separator: ", "))")
        }

    case "add-list":
        guard options.count >= 2 else { fail(usage) }
        let domains = options.dropFirst().map { raw in
            guard let domain = DomainName(raw) else { fail("Not a valid domain: \(raw)") }
            return domain
        }
        var config = try await client.config()
        let existing = config.leaveBehindLists.first { $0.name == options[0] }
        config.leaveBehindLists.removeAll { $0.name == options[0] }
        config.leaveBehindLists.append(
            LeaveBehindList(id: existing?.id ?? UUID(), name: options[0], domains: domains)
        )
        try await client.updateConfig(config)
        print("Saved \(options[0]).")

    case "start":
        let tookOath = options.contains("--take-oath")
        let positional = options.filter { $0 != "--take-oath" }
        guard positional.count >= 3,
              let mode = SessionMode(rawValue: positional[0]),
              let minutes = Double(positional[1])
        else { fail(usage) }
        let config = try await client.config()
        let request = StartRequest(
            mode: mode,
            endAt: Date().addingTimeInterval(minutes * 60),
            leaveBehindIDs: listIDs(named: positional.dropFirst(2), in: config),
            oathTaken: tookOath
        )
        describe(try await client.start(request))

    case "end":
        guard let id = options.first.flatMap(UUID.init(uuidString:)) else { fail(usage) }
        describe(try await client.endTrail(sessionID: id))

    case "rest":
        describe(try await client.requestRestStop())

    case "take-rest":
        let length = options.first.flatMap(Double.init).map { $0 * 60 }
        describe(try await client.startRestStop(length: length))

    case "end-rest":
        describe(try await client.endRestStop())

    case "descent":
        guard !options.isEmpty else { fail(usage) }
        describe(try await client.useDescent(reason: options.joined(separator: " "), scope: .summit))

    default:
        fail(usage)
    }
} catch let error as TapaError {
    fail("Refused: \(error.rawValue)")
} catch DaemonClientError.unreachable {
    fail("Can't reach the Tapa daemon. Is it installed and running?")
} catch {
    fail("Error: \(error)")
}
