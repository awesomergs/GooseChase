# Quarry: Code Map

Where everything lives and what it does. **Read this before searching the codebase.**
**Keep it current:** if you add, rename or delete a file, or change a public function or type, update this file in the same commit.

Owners: **A** = Vision/camera · **B** = hunt flow/data · **C** = Live Activity/platform (Rohan) · **Shared** = ask the team first.

## Targets

| Target | Folder | What it builds |
|---|---|---|
| `Quarry` | `Quarry/` | The iPhone app. Every file in the folder is compiled in automatically (synchronized folder). |
| `QuarryWidgetsExtension` | `QuarryWidgets/` | Widget extension that hosts **only** the Live Activity (Lock Screen, Dynamic Island, Watch Smart Stack). |

One file is compiled into both targets: `Quarry/Shared/HuntActivityAttributes.swift` (set in `project.pbxproj`; don't move it).

## Data flow (one line each)

- **Play:** `ContentView` (Join/Host/Create tabs) → creates `HuntSession(hunt:)` → `session.start()` → `LiveActivityManager.start` → `PlayView` shows the clue → `VerifyCameraView` → `onCleared` → `session.clearCurrent()` (records the split, `LiveActivityManager.cleared`, arms a 3s auto-advance) → `CheckpointClearedView` → "Next clue"/"Finish" (or the timer) → `session.advance()` (`advance` or `end`, runs once per checkpoint) → `HuntFinishedView`.
- **Capture (available for B):** `CameraCaptureView { image in … }` → one `UIImage` per shutter tap; B stores feature prints and a ≤300 px thumbnail, not the full image.
- **Create:** checkpoint editor → photo `UIImage` → `VisionMatcher.makeReferencePrint` → stored in `Checkpoint.referencePrints`.
- **Verify:** camera frame → `VisionMatcher.bestDistance(from:to:)` → `VisionMatcher.score(forDistance:)` → ring progress → sustained match → still capture + verification → success haptic → `onCleared()` exactly once. Empty references block verification.
- **Deep link:** tapping the Live Activity → `quarry://camera` → `.onOpenURL` in `PlayView` → opens the camera.

## Files

### `Quarry/` (app root)
| File | Owner | Contains |
|---|---|---|
| `Info.plist` | C | Extra Info.plist keys merged with the generated ones: `quarry://` URL scheme, `NSLocalNetworkUsageDescription`, `NSBonjourServices` (`_quarry-hunt._tcp/_udp`), `.quarryhunt` exported type + document type. Excluded from Copy Bundle Resources via a membership exception. |
| `QuarryApp.swift` | C | `@main QuarryApp`: SwiftData container for Hunt/Checkpoint; forces light appearance for the ivory theme. |
| `ContentView.swift` | B | `AppTab` and `ContentView`: Join/Host/Create tabs, themed accent, `GameLaunch` full-screen launcher with optional race start, completion history (lastPlayedAt/bestTime), Nearby teardown, demo seeding, stale activity cleanup, join deep links and file import confirmation. Shared `huntThumbnail` helper; private `IncomingPackage` and `ImportHuntSheet`. PlayView lives in Hunt/. |
| `Item.swift` | n/a | Empty placeholder. Delete. |

### `Quarry/Shared/` (contract; change only after telling the team)
| File | Contains |
|---|---|
| `Models.swift` | `enum CheckpointKind { exactMatch, object }` · `@Model Hunt` (`title`, `createdAt`, `shareID: UUID`, `hostName`, `isJoined`, `lastPlayedAt`, `bestTime`, `checkpoints`, computed `orderedCheckpoints`, computed `isPlayable`) · `@Model Checkpoint` (`order`, `clue`, `kindRaw` + computed `kind`, `referencePrints: [Data]`, `thumbnail: Data?`, `targetLabel: String?`, `hunt`, **location:** `latitude: Double?`, `longitude: Double?`, `radiusMeters` (40), `requiresLocation` (false), computed `coordinate: CLLocationCoordinate2D?`; computed `isReady`). |
| `HuntActivityAttributes.swift` | `nonisolated struct HuntActivityAttributes: ActivityAttributes`: fixed `huntTitle`, `totalCheckpoints`, `startDate`; `ContentState` = `checkpointIndex` (1-based), `clue`, `justCleared`. Preview samples: `.preview`, `.searching`, `.cleared`. **Compiled into both targets.** |
| `HuntPackage.swift` | `HuntPackage` / `CheckpointPackage` (Codable, Sendable; `HuntPackage` is `Transferable` via `CodableRepresentation(contentType: .quarryHunt)`), `UTType.quarryHunt` ("com.quarryapp.hunt", `.quarryhunt`), `HuntPackage.load(from: URL)`. B adds `init(hunt:)` / `importHunt(into:)` in `Hunt/HuntPackage+SwiftData.swift`. |
| `RaceMessages.swift` | `PlayerProgress`, `NearbyMessage` (`hello`, `hunt`, `start(at:)`, `progress`, `leaderboard`; `encoded()` / `decode(_:)`), `RoomCode` (`make()`, `joinURL(_:)` → `quarry://join?code=…`, `code(from:)`), `PlayerIdentity` (`id`, `name`, UserDefaults). |

### `Quarry/Hunt/` (B)
| File | Contains |
|---|---|
| `QuarryMetricView.swift` | `QuarryMetricView(title:value:systemImage:)`: reusable adaptive fact card for hunt counts, setup readiness, and elapsed time. |
| `QuarryProgressView.swift` | `QuarryProgressView(cleared:total:)`: actual cleared-count progress with compact segments and a fallback bar for long hunts. |
| `QuarryTheme.swift` | `QuarryTheme(colorScheme:)`: semantic light/dark colors and reusable typography/spacing tokens from DESIGN.md. Owned by B; no shared contract changes. |
| `QuarryCardRow.swift` | `QuarryCardRow` ViewModifier: solid rounded native List row surface, padding, and Increased Contrast outline. |
| `QuarryPrimaryButton.swift` | `QuarryPrimaryButton(title:systemImage:action:)`: native prominent Liquid Glass button with adaptive orange tint, semantic font, and growing label. |
| `HuntThumbnail.swift` | `HuntThumbnail(data:)`: 56 pt photo or running-goose placeholder; decorative accessibility treatment. |
| `HuntListRow.swift` | `HuntListRow(hunt:onStart:)`: adaptive hunt summary, checkpoint setup readiness, tappable summary, explicit Details navigation and prominent Start hunt button; start actions are disabled until isPlayable. No stored play progress. |
| `HuntSession.swift` | `@Observable final class HuntSession`: `hunt`, `currentIndex`, `startDate`, `isFinished`, `splits: [TimeInterval]`, `lastClearedNumber`, `isAwaitingAdvance`; computed `checkpoints`, `current`, `progressText`, `lastSplit`, `totalTime`; methods `start()`, `clearCurrent()` (records the split + `LiveActivityManager.cleared` + arms a 3s auto-advance; does **not** advance), `advance()` (moves to the next checkpoint or finishes; guarded by `isAwaitingAdvance` so the button and timer run it once; calls `RaceSession.shared.reportProgress` when a race is active), `quit()` (cancels the timer + ends). **The only caller of `LiveActivityManager`.** Made `Identifiable` in `Hunt/PlayView.swift`. |
| `PlayView.swift` | `PlayView(session:startAt:onClose:)`: `startAt: Date?` — nil = solo (caller already called `session.start()`), non-nil = race (3-2-1 countdown overlay shown; `session.start()` called at the synced time). Custom top bar (xmark End + running `.timer` + `list.number` leaderboard button when racing), QuarryProgressView cleared-count progress, compact "You're Nth" rank capsule when racing, "Checkpoint N of M", clue card, large "Open camera" button; presents `VerifyCameraView`, handles `quarry://camera`, success haptic; `LeaderboardView` sheet. Shows `CheckpointClearedView` while `isAwaitingAdvance`, and `HuntFinishedView` when `isFinished`. Private: `RaceCountdownView`. Holds `extension HuntSession: Identifiable` and the module-level `mmss(_:)` / `ordinal(_:)` helpers shared with the cleared/finished screens. |
| `CheckpointClearedView.swift` | `CheckpointClearedView(session:)`: the "Checkpoint N cleared!" screen (themed verified-green checkmark, just-cleared checkpoint thumbnail, split time, "You're Nth" when racing, Next clue / Finish button → `session.advance()`). Presented by `PlayView` while `isAwaitingAdvance`; HuntSession's 3s auto-advance also dismisses it. |
| `HuntFinishedView.swift` | `HuntFinishedView(session:onDone:)`: the themed goose finish screen (total time, per-checkpoint split-times list, then `LeaderboardView` when a race is active else a thumbnail grid, Done button). Presented by `PlayView` when `isFinished`. |
| `RacePlaceholders.swift` | Empty placeholder; real Nearby implementations replace the old stubs. |
| `CreateTab.swift` | Authored-hunt query, goose heading/empty state, ivory hunt cards with Details/guarded solo play, delete/share actions, title/checkpoint navigation, and host-name initialization; shared HuntRow for Host. |
| `DemoData.swift` | `DemoData.seedIfEmpty(_ context:)`: inserts a 3-checkpoint "Birthday Hunt" (no reference photos yet). |
| `HuntEditorView.swift` | `HuntEditorView(hunt:path:)`: `Form` to edit a `Hunt`'s title and list its `orderedCheckpoints` (clue + thumbnail). "Add checkpoint" creates a `Checkpoint` with the next `order` and pushes `CheckpointEditorView` by appending to the shared `NavigationPath`; swipe to delete (renormalizes `order`); drag to reorder (`EditButton`); deletes the hunt on exit if it's still an untouched "New Hunt". |
| `CameraPicker.swift` | `CameraPicker(onImage:)`: `UIViewControllerRepresentable` wrapping `UIImagePickerController`; uses `.camera` on device, falls back to `.photoLibrary` in Simulator. Calls `onImage` then dismisses via `@Environment(\.dismiss)`. |
| `CheckpointEditorView.swift` | `CheckpointEditorView(checkpoint:)`: `Form` with a clue `TextField` and a "Reference photos" section showing up to 3 thumbnails. Presents `CameraPicker`, calls `VisionMatcher.makeReferencePrint` on a detached background `Task`, appends to `checkpoint.referencePrints`, and stores a ≤300 px JPEG thumbnail. Shows `ProgressView` while processing and an inline red error on failure. |
| `HuntPackage+SwiftData.swift` | `extension HuntPackage`: `init(hunt: Hunt)` (flattens all checkpoint fields including `referencePrints`, `thumbnail`, location, `shareID`, `hostName`) · `@discardableResult importHunt(into: ModelContext) -> Hunt` (finds existing `Hunt` by `shareID` via `FetchDescriptor + #Predicate`, replaces title/hostName/checkpoints, or inserts a new one). Private helper `makeCheckpoint(from:context:)`. |

### `Quarry/Vision/` (A)
| File | Contains |
|---|---|
| `VisionMatcher.swift` | `nonisolated enum VisionMatcher`: `makeReferencePrint(from: UIImage) throws -> Data` · `bestDistance(from: UIImage, to: [Data]) throws -> Float` (smaller = closer) · `score(forDistance:strong:weak:) -> Double` (0…1; **thresholds still need tuning**). Uses `VNGenerateImageFeaturePrintRequest` + `NSKeyedArchiver`. |
| `VerifyCameraView.swift` | `VerifyCameraView(checkpoint:onCleared:)`: real back-camera preview, live matching ring, 85% threshold held for ~0.5 s, verified auto/manual capture, and exactly-once clearing. Empty references show “Reference photos needed”. Initializer unchanged. |
| `CameraCaptureView.swift` | `CameraCaptureView(title:message:referencePrints:onCaptured:)` (title/message have defaults; optional referencePrints defaults to nil, preserving existing calls): reusable back-camera screen. Returns a `UIImage` on the main actor once per successful shutter tap; stays open for additional photos, caller may dismiss. Close/errors never invoke the callback. Handles permission, Settings, unavailable/interrupted camera, foreground lifecycle, rotation and last-photo preview. Optional verification samples at ~5 Hz, verifies stills, shows score/ring and retry errors, and rejects stale results after lifecycle changes. Private preview/status views. No Photos or SwiftData image persistence. |
| `CameraSession.swift` | `CameraSession`: serial-queue AVFoundation session configuration, start/stop, still capture, latest-frame video delegate and `matchScore(references:rotationAngle:photo:)` for serialized off-main Vision comparisons; private photo delegate retained through capture completion. Internal implementation for `CameraCaptureView`. |

### `Quarry/Nearby/` (A)
| File | Contains |
|---|---|
| `NearbySession.swift` | Real MultipeerConnectivity hosting/joining, room codes, hunt transfer, synchronized start, reconnect handling, race-message forwarding and teardown. |
| `HostTab.swift` | Lists playable/unfinished authored hunts, opens host lobby, routes to Create or launches the synchronized game. |
| `HostLobbyView.swift` | `HostLobbyView(hunt:onStart:)`: QR/code, connected players, Start for everyone, lobby lifecycle. |
| `JoinView.swift` | `JoinTab(linkCode:onStart:)`: name/code/QR entry, imports received hunts, lobby and synchronized launch, joined-game history; private GameRow. |
| `QRCodeView.swift` | QR image generation and display. |
| `QRScannerView.swift` | Camera QR scanning for room-code entry. |
| `HuntTransfer.swift`, `NearbyDebugView.swift` | Empty placeholders; package conversion and production Join/Host screens supersede them. |

### `Quarry/Race/` (C)
| File | Contains |
|---|---|
| `RaceSession.swift` | `@Observable @MainActor RaceSession.shared`: `isActive`, `isHost`, `huntShareID`, `startDate`, sorted `players`, `me`, `myRank`, `racerCount`, `myID`; `sendHandler` (set by NearbySession; nil = solo); `begin(huntShareID:total:isHost:startAt:)`, `reportProgress(cleared:total:)`, `receive(_:)`, `rank(of:)`, `finishTime(of:)`, `end()`; `static sorted(_:)`; `static preview()` for #Previews. |
| `LeaderboardView.swift` | `LeaderboardView(race: = .shared)`: list of `LeaderboardRow`s (rank badge, "You", segmented progress, finish time), spring reordering, selection haptic on rank change; empty state. Previews "Racing" / "Empty". |

### `Quarry/Location/` (A) · stretch goal (contract in SPEC.md)
| File | Contains |
|---|---|
| `LocationService.swift` | *(to be created)* `@Observable @MainActor LocationService.shared`: `location`, `authorization`, `demoMode` (UserDefaults), `start()`, `stop()`, `distance(to:)`, `bearing(to:)`, `isHere(at:)`; `enum Warmth` (freezing…onFire, `label`, `color`). |
| `LocationPickerView.swift` | *(to be created)* `LocationPickerView(checkpoint:)`: map pin, radius slider, "Use my location", "Must be here" toggle. Embedded by B in `CheckpointEditorView`. |
| `HotColdView.swift` | *(to be created)* `HotColdView(checkpoint:)`: warmth card with distance + direction arrow. Embedded by B in `PlayView`. |

### `Quarry/LiveActivity/` (C)
| File | Contains |
|---|---|
| `LiveActivityManager.swift` | `@MainActor final class LiveActivityManager`, `.shared`: `start(huntTitle:totalCheckpoints:firstClue:)` · `cleared(index:clue:) async` (green "cleared" state) · `advance(to:clue:) async` · `end(finalMessage:) async` (activity lingers 3 min) · `endAllStale() async`. Local updates only, no push. |

### `QuarryWidgets/` (C; widget extension target)
| File | Contains |
|---|---|
| `QuarryWidgetsBundle.swift` | `@main QuarryWidgetsBundle`, body = `HuntLiveActivity()` only. |
| `QuarryWidgetsLiveActivity.swift` | `HuntLiveActivity: Widget` (Lock Screen view, Dynamic Island expanded/compact/minimal, `.supplementalActivityFamilies([.small])` for Watch, `widgetURL quarry://camera`) · `ElapsedTimer(start:)` · `LockScreenHuntView` (switches `watchLayout` / `phoneLayout` on `activityFamily`) · `#Preview`s for each presentation. |
| `QuarryWidgets.swift`, `QuarryWidgetsControl.swift` | Empty placeholders. Delete. |
| `Info.plist`, `Assets.xcassets` | Extension point config, widget colors. |

### Project settings (C only, in `Quarry.xcodeproj/project.pbxproj`)
- App Info.plist: generated keys (`NSSupportsLiveActivities = YES`, `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`) merged with `Quarry/Info.plist` (`INFOPLIST_FILE`).
- Deployment target iOS 26.0. App target uses default MainActor isolation; the extension does not.
- Membership exception: `Shared/HuntActivityAttributes.swift` → also in `QuarryWidgetsExtension`.

## Repo root
| File | Purpose |
|---|---|
| `SPEC.md` | Scope, contracts, work split, timeline, demo, conventions, rules for agents. |
| `Quarry-Mockups.png` | Visual concept board for Join, Host, Create, and Live Activities; reference only, not an app asset. |
| `DESIGN.md` | Visual design guide: ivory-white and orange semantic palette, native Apple and Liquid Glass rules, typography, components, screen layouts, and accessibility acceptance criteria; no app behavior changes. |
| `MAP.md` | This file. |
| `PLAN.md` | Afternoon plan (v3: joining + leaderboard): per-person tasks, agent prompts, cut order, demo script, checklist. |
| `AGENTS.md`, `CLAUDE.md` | Point coding agents to `SPEC.md` + `MAP.md`. |
| `README.md` | Quick team overview. |


## App-wide appearance implementation

- `Hunt/QuarryTheme.swift` supplies the adaptive ivory canvas, warm-white cards, orange accent/highlight, charcoal/warm-gray text, and verified green to all app feature views. Public signatures and shared contracts are unchanged.
- `Hunt/PlayView.swift` combines scrollable ivory clue/progress/metric cards and adaptive camera actions with synchronized countdown, rank, leaderboard, cleared and finished screens. Editor Forms retain the same palette.
- Production Join/Host/QR flows replace the temporary debug screen and launcher.
- `Race/LeaderboardView.swift` uses themed rows and rank badges, wrapped name/status layout, and respects Reduce Motion.
- `Vision/CameraCaptureView.swift` retains camera/matching behavior; dark-backed controls use orange, glass Close, and green only after verification, with solid backings for Reduce Transparency.
- `QuarryWidgets/QuarryWidgetsLiveActivity.swift` mirrors the palette in private `ActivityTheme` because it is a separate target; no project membership or shared-model changes.
- `DESIGN.md` includes the complete existing-screen inventory and the native system-surface exceptions.

- Mockup hierarchy refinement: home introduction and hunt-card badges/actions, numbered editor rows and setup metrics, staged checkpoint editor, active progress/clue/metric cards with adaptive bottom actions, and completion summary. All use existing hunt data.

- Playful polish: home uses a compact “Your hunts” heading and existing running-goose artwork (`d f` image asset); the goose also appears in the empty state, photo placeholders, and completion. Repeated camera badges and promotional slogans are removed. Primary buttons use native prominent Liquid Glass.

## Tab redesign and Live Activity concepts

- `Quarry/Design/HuntTabHeader.swift`: shared sky/grass header with the existing running goose for Join, Host, and Create.
- Join, Host, and Create use pale-blue lists and white cards; the existing native TabView and SF Symbol icons are retained. Existing joining, hosting, editing, sharing, deletion, and play actions remain connected.

- `QuarryWidgets/ActivityGoose.swift`: extension-local vector mascot with standard leg rotation transforms; supports running poses; ActivityMascot owns update transitions and accessibility motion handling. No continuous animation or extra activity updates.
- `QuarryWidgets/ActivityGrass.swift`: ground shape with a flat section aligned beneath the Lock Screen goose.
- `QuarryWidgets/QuarryWidgetsLiveActivity.swift`: sky/grass hunting card, green cleared/finished card, white-on-black Dynamic Island and white camera link with black text; preserved timers, camera URL, and Watch support. Progress reflects cleared checkpoints and uses a continuous bar for long hunts.

- `Quarry/Design/HuntTabBackground.swift`: pale-blue tab page background with sky painted through the top safe area; content and native tab-bar placement stay unchanged.
- `Quarry/Design/HuntTabSceneShape.swift`: shallow curved lower edge for the shared header’s grass-to-page transition.

- `QuarryWidgets/ActivityMascot.swift`: shared state-driven mascot for Lock Screen, all Island sizes, and Watch. Native push transition on activity updates; respects Reduce Motion, reduced luminance, and finished state. No continuous background animation.
- Join name/code, hunt title, and checkpoint clue fields have focus-driven keyboard Done controls. Snap it uses its native orange glass button without an opaque label background.
