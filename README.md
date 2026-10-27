# Tapa

*A quieter path to focus.*

Tapa is a native macOS app that blocks distracting websites and apps. Summit Mode can't be cancelled except by using one of a limited number of Descents. Blocking is handled by a system daemon, so it stays on when the app is quit or the Mac restarts.

The name comes from *bertapa*: withdrawing from the crowd to focus.

> Status: early development. Milestone M1 (domain core) is in progress; there is nothing to install yet.

## Layout

| Path | What it is |
| --- | --- |
| `Sources/TapaCore` | Domain rules in pure Swift with no I/O: sessions, `AscentStateMachine`, `EffectivePolicy`, Rituals, Descent, `TrustedClock` |
| `Tests/TapaCoreTests` | Unit tests (Swift Testing) |

The daemon, tracker and app targets will be added in later milestones.

## Development

Requires macOS 13+, Swift 6 and [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`).

```sh
swift build
./scripts/test.sh
./scripts/lint.sh
```

Both scripts also work with only the Command Line Tools installed (no Xcode): `test.sh` adds the flags Swift Testing needs, and `lint.sh` points SwiftLint at the Command Line Tools' SourceKit.

## License

[GPL-3.0-or-later](LICENSE).
