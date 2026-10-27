# 1. Authenticate XPC with a local self-signed certificate

- Status: accepted
- Date: 2026-10-27

## Context

The root daemon holds all session state and must accept commands only from Tapa's own app and tracker. The usual way to check a peer is its code signature, but Tapa is built locally without a paid Apple Developer account: ad-hoc signatures have no Team ID, so there is nothing stable to check against.

macOS 13 added `NSXPCListener.setConnectionCodeSigningRequirement(_:)` and `NSXPCConnection.setCodeSigningRequirement(_:)`, which check a peer against any code signing requirement string. The open question was whether this works with a certificate that nothing trusts.

## Decision

The installer creates a self-signed code signing certificate in the user's login keychain and signs every Tapa binary with it. Both sides check each other with a requirement pinned to that certificate:

```
identifier "<bundle id>" and certificate leaf = H"<SHA-1 of the certificate>"
```

- The daemon calls `setConnectionCodeSigningRequirement` on its listener, requiring the client's identifier.
- Clients call `setCodeSigningRequirement` on their connection, requiring the daemon's identifier.

## Evidence

A spike (branch `spike/xpc-code-signing`) installed a root LaunchDaemon with a Mach service and called it from user-level clients:

| Case | Result |
| --- | --- |
| Sign with the self-signed certificate | Works without marking it trusted |
| Signed client calls the root daemon | Reply received, daemon runs as euid 0 |
| Ad-hoc signed client | Rejected by the listener before the delegate is called |
| Signed client requiring a different daemon identifier | Rejected by the client |

## Consequences

- No Apple Developer account and no trust setting are needed. The installer must not prompt to trust the certificate.
- The certificate hash differs on every machine, so requirement strings are built at install time. The daemon gets its client requirement from its launchd plist. The app and tracker read the daemon requirement from a root-owned file.
- Creating a new certificate invalidates every existing signature. Reinstalling must re-sign all binaries together.
- Any process running as the user that can use the private key could sign a binary that passes the check. This is within the accepted risk in the PRD: the Mac's owner can always take the system apart. The key's access list is limited to `codesign`.
- A rejected client sees the same error as when the daemon isn't running ("Couldn't communicate with a helper application"). The UI can't tell the two apart from that error alone.
- XPC calls handlers on its own queues. In Swift 6, every handler (invalidation, interruption, error, reply) must be `@Sendable`. Otherwise closures written in main-actor code trap at runtime.
- Clients must connect with `NSXPCConnection.Options.privileged` to reach a Mach service in the system domain.
- Not covered: registering the tracker with `SMAppService.agent` under this signing setup. That remains a risk until the tracker milestone.
