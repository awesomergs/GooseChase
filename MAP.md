# GooseChase (Quarry) · Code map

Where everything lives and what it does. **Read this before searching the codebase.** If you add, rename or delete a file, or change a public type or function, update this file in the same commit.

_Rewritten 2026-11-19 from the actual file tree (not from the hackathon plan). The code is still named **Quarry**; the app displays as **GooseChase**._

## Targets

| Target | Folder | Builds |
|---|---|---|
| `Quarry` | `Quarry/` | The iPhone app (iOS 26, Swift 5 mode, default actor isolation = MainActor). Synchronized folder: every file inside is compiled in automatically. |
| `QuarryWidgetsExtension` | `QuarryWidgets/` | Widget extension that hosts **only** the Live Activity (Lock Screen, Dynamic Island, Apple Watch Smart Stack). |
| _(planned)_ `GooseChaseTests` | `GooseChaseTests/` | Swift Testing unit tests. The files exist; the Xcode target does not yet (see `GooseChaseTests/README.md`). |

`Quarry/Shared/HuntActivityAttributes.swift` is compiled into **both** targets (membership exception in `project.pbxproj`; don't move it).

## How the main flows connect

```
Create tab ──► HuntEditorView ──► CheckpointEditorView ──► CameraPicker ──► VisionMatcher.makeReferencePrint
                                                                             └─► Checkpoint.referencePrints + thumbnail (SwiftData)

Host tab ──► HostLobbyView ── NearbySession.startHosting(HuntPackage) ── room code + QR (quarry://join?code=XXXX)
                  │                     ▲  MultipeerConnectivity
Join tab ─────────┼── NearbySession.join(code) ── receives .hunt ── importHunt(into:) ── lobby "You're in!"
 (typed code,     │
  QRScannerView,  └─ "Start for everyone" ── NearbySession.startRace(at: now+4s) ── .start(at:) to every player
  Camera-app link,
  Siri JoinGameIntent)
                                   ▼ (host and players, same Date)
ContentView.launch(hunt, startAt) ──► PlayView (3-2-1 countdown) ──► HuntSession.start() ──► LiveActivityManager.start
   PlayView "Snap it" ──► VerifyCameraView ──► CameraCaptureView + CameraSession ──► VisionMatcher.bestDistance → score
   sustained match + verified still ──► HuntSession.clearCurrent() ──► LiveActivityManager.cleared (green state)
   CheckpointClearedView ── "Next clue" or 3 s timer ──► HuntSession.advance() ──► LiveActivityManager.advance / end
   last checkpoint ──► HuntFinishedView ──► ContentView.finish (bestTime, lastPlayedAt, NearbySession.stop)
```

- **Create → Host lobby:** `HostTab` lists your playable hunts (`!isJoined && isPlayable`); "Host this hunt" opens `HostLobbyView`, which flattens the hunt into a `HuntPackage` and starts advertising a 4-character `RoomCode`.
- **Join:** `JoinTab` connects by typed code, the in-app QR scanner, a `quarry://join?code=XXXX` link (iPhone Camera app or Siri), then imports the received package as a joined hunt (`isJoined = true`) and waits in the lobby. If the host drops, "Start now" lets the player play offline.
- **Synced start:** the host sends `.start(at:)` about 4 s in the future; `PlayView` counts down and calls `session.start()` at that instant on every phone. Solo play (`startAt == nil`) starts immediately.
- **Play → Vision clear:** `CameraCaptureView` samples frames at ~5 Hz through `CameraSession.matchScore`, smooths the score, needs ≥ 0.85 (distance ≤ 0.5325) held briefly, then verifies a still photo before calling `onCleared` exactly once.
- **Live Activity:** `HuntSession` is the only caller of `LiveActivityManager` (start → cleared → advance → end). Tapping the activity opens `quarry://camera`.
- **Finish:** `HuntFinishedView` shows total and split times; `ContentView.finish` saves `bestTime`/`lastPlayedAt` and tears down the nearby connection.
- **Siri / Shortcuts / Action Button:** `CurrentClueIntent` reads `HuntSession.active`; `SnapCheckpointIntent` opens `quarry://camera`; `JoinGameIntent` opens `quarry://join?code=XXXX`.
- **Deep links:** `quarry://join?code=XXXX` → `ContentView.onOpenURL` → `RoomCode.code(from:)` → Join tab auto-joins. `quarry://camera` → `PlayView.onOpenURL` → camera for the current checkpoint (only while a game is open). A `.quarryhunt` file (AirDrop/Messages) → `ContentView.onOpenURL` → `ImportHuntSheet`.
- **Dormant:** the live leaderboard (`Race/`). `RaceSession.begin(...)` is never called, so `isActive` is always false and race UI never shows. See `docs/phase0/DEAD_CODE.md`.

## Files

### Repo root
| File | Purpose |
|---|---|
| `README.md` | Judge/portfolio overview, Apple features, how to run, credits, roadmap. |
| `MAP.md` | This file. |
| `DESIGN.md` | The design system (colors, type, sky/grass scene, goose moods, glass-for-controls rule, components). |
| `PLAN.md`, `SPEC.md` | **Archived** hackathon planning docs (afternoon plan; scope/contracts/rules). Superseded by README/MAP/DESIGN and `docs/phase0/`. |
| `AGENTS.md`, `CLAUDE.md` | Identical instructions for coding agents (read MAP, keep contracts, update MAP). Still point at SPEC.md. |
| `NIGHTLY_SUMMARY.md` | Report from the overnight Phase 0 run. |
| `docs/phase0/` | `DEAD_CODE.md`, `THEME_MERGE_PLAN.md`, `ISSUES.md`: Phase 0 analysis and issue drafts. `ci.yml`: the CI workflow, waiting to be copied to `.github/workflows/`. |
| `GooseChaseTests/` | Swift Testing unit tests + `README.md` on adding the test target. Not compiled until the target exists. |
| `.github/workflows/ci.yml` | _(after copying from `docs/phase0/ci.yml`)_ GitHub Actions build and a commented-out test job. |
| `IconLayers/` | Source PNG/SVG layers and previews for the Icon Composer icon. |
| `.agents/skills/` | Agent skill packs (SwiftUI, SwiftData, Swift concurrency). Not part of the app. |
| `Claude outputs/` | Scratch output from AI helpers (gitignored). |
| `.gitignore` | Ignores `.DS_Store`, `xcuserdata/`, build output, `.swiftpm/`, `Claude outputs/`. |

### `Quarry/` (app root)
| File | What it does |
|---|---|
| `QuarryApp.swift` | `@main`: builds the SwiftData container (`Hunt`, `Checkpoint`), shows `ContentView`, forces light appearance. |
| `ContentView.swift` | App shell: `AppTab` + Join/Host/Create `TabView`, the game launcher (`GameLaunch` → full-screen `PlayView`), `finish` (best time, Nearby teardown), `onOpenURL` for join links and `.quarryhunt` files, demo seeding, stale Live Activity cleanup; shared `huntThumbnail(_:size:)`; private `ImportHuntSheet`. |
| `Info.plist` | Extra keys merged into the generated plist: `quarry://` URL scheme, Local Network usage + Bonjour `_quarry-hunt._tcp/_udp`, `.quarryhunt` exported UTType and document type, Siri alternative app names. |
| `Assets.xcassets` | Accent color, app icon set, and two near-identical `GooseChase` / `GooseChase 1` folders (icon dataset + `d f` goose image); likely an accidental duplicate. |
| `GooseChase.icon` | Icon Composer layered app icon (light/dark/tinted). |

### `Quarry/Design/` (brand look)
| File | What it does |
|---|---|
| `Theme.swift` | `Brand` colors from the icon, `SkyBackground`, `GrassHill`/`GrassShape`, `.gooseProminent()` main-action button, `.skyCard()` (glass card; to be replaced). |
| `GooseView.swift` | Animated goose mascot drawn with `Canvas` + `TimelineView`; `GooseMood` = `.running`, `.waiting`, `.honk`, `.celebrate`; still image with Reduce Motion. |
| `HuntTabHeader.swift` | Sky + grass header with title, subtitle and running goose at the top of the Join/Host/Create lists. |
| `HuntTabBackground.swift` | Pale-sky list background that keeps the status-bar area sky blue. |
| `HuntTabSceneShape.swift` | Curved bottom edge for the tab header scene. |

### `Quarry/Hunt/` (create + play)
| File | What it does |
|---|---|
| `CreateTab.swift` | Create tab: your authored hunts (`!isJoined`), New hunt, edit/play solo/share (AirDrop)/delete; defines `HuntRow` (also used by Host). |
| `HuntEditorView.swift` | Edit a hunt: title, metric tiles, ordered checkpoints (add/delete/reorder); deletes an untouched "New Hunt" on exit. |
| `CheckpointEditorView.swift` | Edit a checkpoint: clue, up to 3 reference photos → feature prints off the main thread, ≤300 px JPEG thumbnail. |
| `CameraPicker.swift` | `UIImagePickerController` wrapper (camera on device, photo library in Simulator). |
| `HuntSession.swift` | `@Observable` play state: current index, split times, cleared/advance guard with 3 s auto-advance, quit; the only caller of `LiveActivityManager`. |
| `PlayView.swift` | Clue screen on the sky (top bar with End + timer, progress segments, clue card, Snap it), race countdown overlay, camera presentation, `quarry://camera`; module-level `mmss(_:)` and `ordinal(_:)`. |
| `CheckpointClearedView.swift` | "Honk! Checkpoint N cleared" screen with thumbnail, split time, Next clue/Finish. |
| `HuntFinishedView.swift` | Finish screen: total time, per-checkpoint splits, photo grid (or leaderboard when racing), Done. |
| `HuntPackage+SwiftData.swift` | `HuntPackage(hunt:)` and `importHunt(into:)` (upsert by `shareID`). |
| `DemoData.swift` | Seeds a 3-checkpoint "Birthday Hunt" (no photos) on first launch. |
| `QuarryTheme.swift` | Cody's semantic palette + spacing/radius tokens (ivory/orange). Live; to be merged into `Brand`. |
| `QuarryMetricView.swift` | Metric tile (title, value, symbol); used by `HuntEditorView`. |

### `Quarry/Nearby/` (joining + hosting)
| File | What it does |
|---|---|
| `NearbySession.swift` | MultipeerConnectivity host/join by room code, hunt transfer, synced `.start(at:)`, retries/reconnects, forwards race messages to `RaceSession`; `MultipeerBridge` delegate. |
| `JoinView.swift` | `JoinTab`: name, Scan QR / room code entry, connection status, lobby with offline "Start now" fallback, "Your games" (joined hunts, best times). |
| `HostTab.swift` | Host tab: ready-to-host and needs-work hunts; opens `HostLobbyView`. |
| `HostLobbyView.swift` | Host lobby: QR + big room code, joined players, Start solo / Start for everyone. |
| `QRCodeView.swift` | Renders a crisp QR for a URL (Core Image). |
| `QRScannerView.swift` | VisionKit `DataScannerViewController` QR scanner; accepts `quarry://join?code=` or a bare 4-character code. |

### `Quarry/Vision/` (camera + matching)
| File | What it does |
|---|---|
| `VisionMatcher.swift` | Feature prints: `makeReferencePrint(from:)`, `bestDistance(from:to:)` (whole frame, center crop, salient-object crop), `score(forDistance:strong:weak:)` (0.45 → 1, 1.0 → 0). |
| `CameraSession.swift` | AVFoundation session on a serial queue, latest frame, still capture, smoothed `matchScore(references:rotationAngle:photo:)`. |
| `CameraCaptureView.swift` | Full-screen camera: preview, match ring, 0.85 threshold, auto/manual verified capture, permission/retry states; also used for plain reference capture. |
| `VerifyCameraView.swift` | Thin wrapper: `CameraCaptureView` with a checkpoint's clue and reference prints → `onCleared`. |

### `Quarry/Intents/`
| File | What it does |
|---|---|
| `GooseChaseIntents.swift` | `CurrentClueIntent`, `SnapCheckpointIntent`, `JoinGameIntent`, `GooseChaseShortcuts` phrases; `HuntSession.active` weak reference. |

### `Quarry/LiveActivity/`
| File | What it does |
|---|---|
| `LiveActivityManager.swift` | Starts/updates/ends the hunt Live Activity (local updates only, works with a free team); `endAllStale()`. |

### `Quarry/Race/` (dormant live leaderboard)
| File | What it does |
|---|---|
| `RaceSession.swift` | `@Observable` standings: merge/sort `PlayerProgress`, host broadcasts leaderboard, players send progress. **Dormant** — `begin` is never called, so every race branch elsewhere is dead at runtime; parked for Phase 2, not removed. |
| `LeaderboardView.swift` | Leaderboard list with rank badges and progress segments (QuarryTheme colors). |

### `Quarry/Shared/` (wire formats and models; change carefully)
| File | What it does |
|---|---|
| `Models.swift` | SwiftData `Hunt` (title, shareID, hostName, isJoined, bestTime, checkpoints, `isPlayable`) and `Checkpoint` (clue, kind, referencePrints, thumbnail, targetLabel, optional location, `isReady`); `CheckpointKind`. |
| `HuntPackage.swift` | Codable/Transferable `HuntPackage` + `CheckpointPackage`, `UTType.quarryHunt` (`com.quarryapp.hunt`), `load(from:)`. |
| `RaceMessages.swift` | `PlayerProgress`, `NearbyMessage` (hello/hunt/start/progress/leaderboard), `RoomCode` (make, joinURL, code(from:)), `PlayerIdentity` (UserDefaults id + name). |
| `HuntActivityAttributes.swift` | Live Activity attributes + `ContentState`; preview samples. **In both targets.** |

### `QuarryWidgets/` (widget extension)
| File | What it does |
|---|---|
| `QuarryWidgetsBundle.swift` | `@main` bundle containing only `HuntLiveActivity`. |
| `QuarryWidgetsLiveActivity.swift` | `HuntLiveActivity`: Lock Screen, Dynamic Island (expanded/compact/minimal), Watch Smart Stack (`.supplementalActivityFamilies([.small])`), `widgetURL quarry://camera`; `HuntProgress`, `ProgressRing`, `ElapsedTimer`, `LockScreenHuntView`; previews. |
| `ActivityGoose.swift` | Static goose drawing for the activity (mirrors Brand colors by hand). |
| `ActivityMascot.swift` | Goose with a push transition between states (respects Reduce Motion / luminance). |
| `ActivityGrass.swift` | Grass shape under the goose. |
| `Info.plist`, `Assets.xcassets` | Extension point config, widget colors. |

## Project settings (`Quarry.xcodeproj`)
- Deployment target iOS 26.0; `SWIFT_VERSION = 5.0`; app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency.
- Generated Info.plist keys: `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` (location is not built yet), `NSSupportsLiveActivities`, display name GooseChase; merged with `Quarry/Info.plist`.
- Bundle IDs `rgs.Quarry` and `rgs.Quarry.QuarryWidgets`. The project-level and target-level `DEVELOPMENT_TEAM` values differ (team members' teams); set both to your Personal Team.
- No shared scheme yet (schemes live in gitignored `xcuserdata/`). Share the `Quarry` scheme before relying on CI.
