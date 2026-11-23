# GooseChaseTests

Unit tests for the pure logic in the app, written with **Swift Testing** (`import Testing`, `@testable import Quarry`). They need no camera, SwiftData container, MultipeerConnectivity or ActivityKit request, so they run in the Simulator in a few seconds.

**Status:** the files are written but the Xcode test target does not exist yet, and they have **not been compiled** (they were written overnight without access to Xcode). Expect to fix a small typo or two the first time you build.

| File | Covers |
|---|---|
| `RoomCodeTests.swift` | `RoomCode.make()`, alphabet, `joinURL(_:)`, `code(from:)` with valid, lowercase, wrong-scheme/host and garbage links; known gaps as `withKnownIssue` |
| `VisionMatcherScoreTests.swift` | `VisionMatcher.score(forDistance:)`: bounds, monotonicity, strong/weak cut-offs, the 0.85 clear threshold (distance 0.5325), custom thresholds, NaN (known gap) |
| `HuntPackageTests.swift` | `HuntPackage` JSON round-trip, `load(from:)`, `UTType.quarryHunt`; `NearbyMessage` round-trip for every case |
| `HelperTests.swift` | `mmss(_:)`, `ordinal(_:)`, `CheckpointKind` raw values, Live Activity `ContentState` round-trip and 4 KB budget |
| `CheckpointModelTests.swift` | `Checkpoint.isReady`, `kind`, `coordinate`, defaults (model objects without a container) |
| `RaceSessionTests.swift` | `RaceSession.sorted(_:)`, `LeaderboardRow.format` (delete if you remove `Quarry/Race/`) |
| `AppContractTests.swift` | `quarry://` scheme and Bonjour service in Info.plist, `NearbySession.serviceType`, `PlayerIdentity.id` (needs a hosted target) |

`withKnownIssue` marks current behavior that is probably wrong but was deliberately not fixed (no app code was changed). Those tests pass while the issue exists; when you fix the code, Swift Testing reports "known issue was not recorded" so you know to turn them into plain expectations.

## Add the test target (one time)

1. Open `Quarry.xcodeproj` in Xcode 26.
2. **File → New → Target…** → iOS → **Unit Testing Bundle** → Next.
3. Product Name: **`GooseChaseTests`**. Testing System: **Swift Testing**. Target to be Tested: **Quarry**. Finish.
4. Xcode adds a synchronized folder for the new target. Because a `GooseChaseTests/` folder already exists at the repo root, one of two things happens:
   - **It reuses this folder** and drops a template `GooseChaseTests.swift` in it. Delete that template file (Move to Trash). Done.
   - **It creates a second folder** (for example `GooseChaseTests 2/`). Delete that group (Move to Trash), then right-click the project in the navigator → **Add Files to "Quarry"…** → select this `GooseChaseTests` folder → choose **Create folders** (synchronized) → tick only the **GooseChaseTests** target → Add.
5. Select the `GooseChaseTests` target → **General**: Host Application = **Quarry** (needed by `AppContractTests`). **Build Settings**: Swift Language Version = Swift 5 (match the app), iOS Deployment Target = 26.0.
6. Make sure **`README.md` is not in Copy Bundle Resources** of the test target (harmless, but untidy). If it is, remove it, or add a membership exception for it.
7. Share the scheme so CI can see it: **Product → Scheme → Manage Schemes…** → tick **Shared** for `Quarry`. Then edit the `Quarry` scheme → **Test** → make sure `GooseChaseTests` is listed.
8. Pick an iPhone Simulator and press **⌘U**.

Expected result: all tests pass, with the `withKnownIssue` tests shown as known issues (5 in all: 4 in `RoomCodeTests`, 1 in `VisionMatcherScoreTests`).

If `CheckpointModelTests` crashes on your SDK (creating `@Model` objects without a container), delete that file or wrap it in an in-memory `ModelContainer`.

## Run from Terminal

```sh
xcodebuild test \
  -project Quarry.xcodeproj -scheme Quarry \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Change the simulator name to one you have (`xcrun simctl list devices available`).

## Adding tests

- Keep tests pure: pass values in, check values out. Anything that needs the camera, a real `ModelContainer`, nearby networking or a running Live Activity belongs in a UI test or a manual checklist.
- Mark suites `@MainActor`: the app target uses MainActor as its default isolation, so most app types are main-actor isolated.
- Name files `<Thing>Tests.swift`; one `@Suite` per type.
