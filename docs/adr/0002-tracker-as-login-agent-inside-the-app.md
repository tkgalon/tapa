# 2. Run the tracker as a login agent inside Tapa.app

- Status: accepted
- Date: 2026-10-28

## Context

Mist needs a process that runs as the user while the window is closed: it reads the active tab's address, sends tabs on Leave Behind to Mist, and serves the Mist page. That process can't be the daemon, which runs as root and must not open a port or drive other apps.

ADR 0001 left one risk open: whether `SMAppService.agent` accepts an agent inside an app signed with the local self-signed certificate. Two more had to be proven before building on it. Apple events need the user's permission per browser, and it wasn't known which name that permission would carry, or whether it would survive the re-signing every build does.

## Decision

TapaTracker ships inside Tapa.app as `Contents/MacOS/TapaTracker`, with its launchd plist at `Contents/Library/LaunchAgents/id.tapa.tracker.plist`. The app registers it with `SMAppService.agent(plistName:)` when it opens. The plist sets `RunAtLoad` and `KeepAlive`, so launchd starts it at login and restarts it if it stops.

The tracker is signed on its own as `id.tapa.tracker` before the app bundle is signed as `id.tapa.app`, both with the local certificate. The daemon's client requirement already accepts `id.tapa.tracker`.

The tracker drives browsers with Apple events and serves Mist with `NWListener` bound to `127.0.0.1` only.

## Evidence

A spike on branch `feat/m4-mist` built the tracker with a fixed blocked domain and ran it on macOS 26:

| Case | Result |
| --- | --- |
| Register the agent from the self-signed app | launchd runs it (`state = running`), no approval needed |
| Read Chrome's active tab address and replace it | tiktok.com is sent to `127.0.0.1:47800/mist` within a second |
| Name on the Automation permission | "Tapa", the app, not the tracker binary |
| Rebuild and re-sign the app, restart the tracker | Permission kept, no second prompt |
| Fetch Mist from `127.0.0.1` | Page served |
| Fetch Mist from the Mac's Wi-Fi address | Refused |
| Memory while idle | About 24 MB footprint |

## Consequences

- The user grants Automation once per browser, under the name they know. `NSAppleEventsUsageDescription` lives in the app's Info.plist.
- Re-signing with the same certificate keeps the permission, since the designated requirement doesn't change. Creating a new certificate, as in ADR 0001, would ask again.
- `tell application` launches a browser that isn't running, so the tracker checks that the browser is open before sending it Apple events.
- Replacing the app bundle doesn't restart a running tracker. Development builds restart it with `launchctl kickstart -k gui/<uid>/id.tapa.tracker`.
- The tracker's footprint sits at the PRD's 25 MB limit while it links AppKit. Linking less, or reading running apps another way, is the first thing to try if it grows.
- A website can request `127.0.0.1:47800` like any address. Mist only shows a page and never changes a session, so this exposes nothing. Actions go through `tapa://`, which only opens a confirmation in the app.
- Not covered yet: Safari, Arc, Brave, Edge and Opera, and pausing while the screen is locked.
