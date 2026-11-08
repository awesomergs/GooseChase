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

- **Play:** `ContentView` → creates `HuntSession(hunt:)` → `session.start()` → `LiveActivityManager.start` → `PlayView` shows the clue → `VerifyCameraView` → `onCleared` → `session.clearCurrent()` → `LiveActivityManager.cleared`, then `advance` or `end`.
- **Capture (available for B):** `CameraCaptureView { image in … }` → one `UIImage` per shutter tap; B stores feature prints and a ≤300 px thumbnail, not the full image.
- **Create:** checkpoint editor → photo `UIImage` → `VisionMatcher.makeReferencePrint` → stored in `Checkpoint.referencePrints`.
- **Verify:** camera frame → `VisionMatcher.bestDistance(from:to:)` → `VisionMatcher.score(forDistance:)` → ring progress → sustained match → still capture + verification → success haptic → `onCleared()` exactly once. Empty references block verification.
- **Deep link:** tapping the Live Activity → `quarry://camera` → `.onOpenURL` in `PlayView` → opens the camera.

## Files

### `Quarry/` (app root)
| File | Owner | Contains |
|---|---|---|
| `Info.plist` | C | Extra Info.plist keys merged with the generated ones: `quarry://` URL scheme, `NSLocalNetworkUsageDescription`, `NSBonjourServices` (`_quarry-hunt._tcp/_udp`), `.quarryhunt` exported type + document type. Excluded from Copy Bundle Resources via a membership exception. |
| `QuarryApp.swift` | C | `@main QuarryApp`: SwiftData `ModelContainer` with schema `[Hunt, Checkpoint]`. |
| `ContentView.swift` | B | `ContentView` (`NavigationStack(path: NavigationPath)` hunt list with first-checkpoint thumbnail, "+" creates a `Hunt` and pushes `HuntEditorView`, per-row Edit/Delete swipe actions; seeds demo data, ends stale Live Activities on launch; registers `navigationDestination` for both `Hunt` and `Checkpoint`); `PlayView(session:onClose:)` (clue screen, opens the camera, handles `quarry://camera`, finish state). Temporary; B may split it into `Hunt/` files. |
| `Item.swift` | n/a | Empty placeholder. Delete. |

### `Quarry/Shared/` (contract; change only after telling the team)
| File | Contains |
|---|---|
| `Models.swift` | `enum CheckpointKind { exactMatch, object }` · `@Model Hunt` (`title`, `createdAt`, `shareID: UUID`, `hostName`, `checkpoints`, computed `orderedCheckpoints`, computed `isPlayable`) · `@Model Checkpoint` (`order`, `clue`, `kindRaw` + computed `kind`, `referencePrints: [Data]`, `thumbnail: Data?`, `targetLabel: String?`, `hunt`, **location:** `latitude: Double?`, `longitude: Double?`, `radiusMeters` (40), `requiresLocation` (false), computed `coordinate: CLLocationCoordinate2D?`; computed `isReady`). |
| `HuntActivityAttributes.swift` | `nonisolated struct HuntActivityAttributes: ActivityAttributes`: fixed `huntTitle`, `totalCheckpoints`, `startDate`; `ContentState` = `checkpointIndex` (1-based), `clue`, `justCleared`. Preview samples: `.preview`, `.searching`, `.cleared`. **Compiled into both targets.** |
| `HuntPackage.swift` | `HuntPackage` / `CheckpointPackage` (Codable, Sendable; `HuntPackage` is `Transferable` via `CodableRepresentation(contentType: .quarryHunt)`), `UTType.quarryHunt` ("com.quarryapp.hunt", `.quarryhunt`), `HuntPackage.load(from: URL)`. B adds `init(hunt:)` / `importHunt(into:)` in `Hunt/HuntPackage+SwiftData.swift`. |
| `RaceMessages.swift` | `PlayerProgress`, `NearbyMessage` (`hello`, `hunt`, `start(at:)`, `progress`, `leaderboard`; `encoded()` / `decode(_:)`), `RoomCode` (`make()`, `joinURL(_:)` → `quarry://join?code=…`, `code(from:)`), `PlayerIdentity` (`id`, `name`, UserDefaults). |

### `Quarry/Hunt/` (B)
| File | Contains |
|---|---|
| `HuntSession.swift` | `@Observable final class HuntSession`: `hunt`, `currentIndex`, `startDate`, `isFinished`; computed `checkpoints`, `current`, `progressText`; methods `start()`, `clearCurrent()`, `quit()`. **The only caller of `LiveActivityManager`.** Made `Identifiable` in `ContentView.swift`. |
| `DemoData.swift` | `DemoData.seedIfEmpty(_ context:)`: inserts a 3-checkpoint "Birthday Hunt" (no reference photos yet). |
| `HuntEditorView.swift` | `HuntEditorView(hunt:path:)`: `Form` to edit a `Hunt`'s title and list its `orderedCheckpoints` (clue + thumbnail). "Add checkpoint" creates a `Checkpoint` with the next `order` and pushes `CheckpointEditorView` by appending to the shared `NavigationPath`; swipe to delete (renormalizes `order`); drag to reorder (`EditButton`); deletes the hunt on exit if it's still an untouched "New Hunt". |
| `CameraPicker.swift` | `CameraPicker(onImage:)`: `UIViewControllerRepresentable` wrapping `UIImagePickerController`; uses `.camera` on device, falls back to `.photoLibrary` in Simulator. Calls `onImage` then dismisses via `@Environment(\.dismiss)`. |
| `CheckpointEditorView.swift` | `CheckpointEditorView(checkpoint:)`: `Form` with a clue `TextField` and a "Reference photos" section showing up to 3 thumbnails. Presents `CameraPicker`, calls `VisionMatcher.makeReferencePrint` on a detached background `Task`, appends to `checkpoint.referencePrints`, and stores a ≤300 px JPEG thumbnail. Shows `ProgressView` while processing and an inline red error on failure. |

### `Quarry/Vision/` (A)
| File | Contains |
|---|---|
| `VisionMatcher.swift` | `nonisolated enum VisionMatcher`: `makeReferencePrint(from: UIImage) throws -> Data` · `bestDistance(from: UIImage, to: [Data]) throws -> Float` (smaller = closer) · `score(forDistance:strong:weak:) -> Double` (0…1; **thresholds still need tuning**). Uses `VNGenerateImageFeaturePrintRequest` + `NSKeyedArchiver`. |
| `VerifyCameraView.swift` | `VerifyCameraView(checkpoint:onCleared:)`: real back-camera preview, live matching ring, 85% threshold held for ~0.5 s, verified auto/manual capture, and exactly-once clearing. Empty references show “Reference photos needed”. Initializer unchanged. |
| `CameraCaptureView.swift` | `CameraCaptureView(title:message:referencePrints:onCaptured:)` (title/message have defaults; optional referencePrints defaults to nil, preserving existing calls): reusable back-camera screen. Returns a `UIImage` on the main actor once per successful shutter tap; stays open for additional photos, caller may dismiss. Close/errors never invoke the callback. Handles permission, Settings, unavailable/interrupted camera, foreground lifecycle, rotation and last-photo preview. Optional verification samples at ~5 Hz, verifies stills, shows score/ring and retry errors, and rejects stale results after lifecycle changes. Private preview/status views. No Photos or SwiftData image persistence. |
| `CameraSession.swift` | `CameraSession`: serial-queue AVFoundation session configuration, start/stop, still capture, latest-frame video delegate and `matchScore(references:rotationAngle:photo:)` for serialized off-main Vision comparisons; private photo delegate retained through capture completion. Internal implementation for `CameraCaptureView`. |

### `Quarry/Nearby/` (A) · planned (PLAN.md v3 A2–A4)
| File | Contains |
|---|---|
| `NearbySession.swift` | *(to be created)* MultipeerConnectivity host/join by room code, `send(_:)`, `receivedHunt`, `startAt`, forwards race messages to `RaceSession`. |
| `QRCodeView.swift`, `HostLobbyView.swift`, `JoinView.swift` | *(to be created)* QR display, host lobby with "Start for everyone", join screen with code field + QR scanner. |

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
| `MAP.md` | This file. |
| `PLAN.md` | Afternoon plan (v3: joining + leaderboard): per-person tasks, agent prompts, cut order, demo script, checklist. |
| `AGENTS.md`, `CLAUDE.md` | Point coding agents to `SPEC.md` + `MAP.md`. |
| `README.md` | Quick team overview. |
