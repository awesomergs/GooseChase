# GooseChaseTests

Unit tests for the pure logic in the app, written with **Swift Testing** (`import Testing`, `@testable import GooseChase`). They need no camera, SwiftData container, MultipeerConnectivity or ActivityKit request, so they run in the Simulator in a few seconds.

**Status:** the `GooseChaseTests` target exists and is wired into the `Quarry` scheme's Test action. All tests pass, 0 known issues.

| File | Covers |
|---|---|
| `RoomCodeTests.swift` | `RoomCode.make()`, alphabet, `joinURL(_:)`, `code(from:)` with valid, lowercase, wrong-scheme/host and malformed links |
| `VisionMatcherScoreTests.swift` | `VisionMatcher.score(forDistance:)`: bounds, monotonicity, strong/weak cut-offs, the 0.85 clear threshold (distance 0.5325), custom thresholds, NaN |
| `HuntPackageTests.swift` | `HuntPackage` JSON round-trip, `load(from:)`, `UTType.quarryHunt`; `NearbyMessage` round-trip for every case |
| `HelperTests.swift` | `mmss(_:)`, `ordinal(_:)`, `CheckpointKind` raw values, Live Activity `ContentState` round-trip and 4 KB budget |
| `CheckpointModelTests.swift` | `Checkpoint.isReady`, `kind`, `coordinate`, defaults (model objects without a container) |
| `RaceSessionTests.swift` | `RaceSession.sorted(_:)`, `LeaderboardRow.format` (delete if you remove `GooseChase/Race/`) |
| `AppContractTests.swift` | `quarry://` scheme and Bonjour service in Info.plist, `NearbySession.serviceType`, `PlayerIdentity.id` (needs a hosted target) |

## Run from Xcode

1. Open `GooseChase.xcodeproj`.
2. Pick any iPhone Simulator as the run destination.
3. Press **⌘U**.

## Run from Terminal

```sh
xcodebuild test \
  -project GooseChase.xcodeproj -scheme Quarry \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Change the simulator name to one you have (`xcrun simctl list devices available`). CI doesn't hard-code a name — it picks the first available iPhone simulator on the runner at the time (see `.github/workflows/ci.yml`).

If `CheckpointModelTests` crashes on your SDK (creating `@Model` objects without a container), delete that file or wrap it in an in-memory `ModelContainer`.

## Adding tests

- Keep tests pure: pass values in, check values out. Anything that needs the camera, a real `ModelContainer`, nearby networking or a running Live Activity belongs in a UI test or a manual checklist.
- Mark suites `@MainActor`: the app target uses MainActor as its default isolation, so most app types are main-actor isolated.
- Name files `<Thing>Tests.swift`; one `@Suite` per type.
