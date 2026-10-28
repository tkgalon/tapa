# 3. Load the tracker as a classic launch agent

- Status: accepted
- Date: 2026-10-28
- Supersedes: [ADR 0002](0002-tracker-as-login-agent-inside-the-app.md), for how the tracker is started

## Context

ADR 0002 registered TapaTracker with `SMAppService.agent`. The spike worked on a fresh registration, but the first rebuild broke it for good. launchd stopped starting the tracker (exit 78, `EX_CONFIG`), and Background Task Management logged `effectiveDisposition: FATAL ERROR - fullPath is nil, container=(null)` for the item.

The item keeps a SHA-256 checksum of the tracker and a link to the app that registered it. A rebuilt app changes both. Unregistering and registering again from the app didn't help: macOS kept the same broken item (same BTM uuid), and only `sfltool resetbtm`, which resets every login item on the Mac and needs a restart, clears it. Without a Developer ID, every update of Tapa would hit the same wall.

## Decision

The tracker is a helper app inside Tapa.app, `Contents/Library/LoginItems/TapaTracker.app`, and Tapa loads it as a classic per-user launch agent:

- When Tapa opens, it writes `~/Library/LaunchAgents/id.tapa.tracker.plist` pointing at the tracker in its own bundle, with `RunAtLoad`, `KeepAlive` and `AssociatedBundleIdentifiers` set to `id.tapa.app`.
- If the plist changed or the agent isn't loaded, Tapa runs `launchctl bootout` and `launchctl bootstrap gui/<uid>`. Otherwise it runs `launchctl kickstart -k`, so a new build replaces the running tracker.
- A leftover `SMAppService` registration from ADR 0002 is unregistered first, since it holds the same label.
- The helper has its own Info.plist with `LSBackgroundOnly`, `CFBundleName` Tapa and `NSAppleEventsUsageDescription`, so the Automation prompt names Tapa and says why. The same plist is also embedded in the binary.
- A binary in `Tapa.app/Contents/MacOS` is taken for part of Tapa.app and uses its Info.plist. The tracker then showed in the Dock as a second Tapa that came back when quit, since launchd restarts it. As a helper app of its own it stays background only.

## Evidence

| Case | Result |
| --- | --- |
| Open Tapa after a fresh build | Agent loaded from `~/Library/LaunchAgents`, tracker running |
| Rebuild twice in a row and reopen | Tracker running again each time, new pid |
| Mist status endpoint after a rebuild | Answers |

## Consequences

- No checksum ties the agent to one build, so rebuilds and updates just work. launchd runs whatever is at the path.
- Moving Tapa.app moves the agent with it the next time Tapa opens, since the plist is written from the running copy.
- The tracker is its own responsible process now, not the app. The Automation permission granted to "Tapa" in the spike doesn't carry over: the tracker asks once per browser, under the name in its embedded Info.plist.
- macOS still lists the agent under Login Items, as a background item of an unidentified developer. Turning it off there stops Mist, not blocking.
- Uninstalling must remove the plist and unload the agent. The uninstall script and the app's Uninstall need that step.
