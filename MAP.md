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
- **Verify (next milestone; not connected yet):** camera frame → `VisionMatcher.bestDistance(from:to:)` → `VisionMatcher.score(forDistance:)` → ring progress → auto-capture → `onCleared()`.
- **Deep link:** tapping the Live Activity → `quarry://camera` → `.onOpenURL` in `PlayView` → opens the camera.

## Files

### `Quarry/` (app root)
| File | Owner | Contains |
|---|---|---|
| `QuarryApp.swift` | C | `@main QuarryApp`: SwiftData `ModelContainer` with schema `[Hunt, Checkpoint]`. |
| `ContentView.swift` | B | `ContentView` (hunt list, seeds demo data, ends stale Live Activities on launch); `PlayView(session:onClose:)` (clue screen, opens the camera, handles `quarry://camera`, finish state). Temporary; B may split it into `Hunt/` files. |
| `Item.swift` | n/a | Empty placeholder. Delete. |

### `Quarry/Shared/` (contract; change only after telling the team)
| File | Contains |
|---|---|
| `Models.swift` | `enum CheckpointKind { exactMatch, object }` · `@Model Hunt` (`title`, `createdAt`, `checkpoints`, computed `orderedCheckpoints`) · `@Model Checkpoint` (`order`, `clue`, `kindRaw` + computed `kind`, `referencePrints: [Data]`, `thumbnail: Data?`, `targetLabel: String?`, `hunt`). |
| `HuntActivityAttributes.swift` | `nonisolated struct HuntActivityAttributes: ActivityAttributes`: fixed `huntTitle`, `totalCheckpoints`, `startDate`; `ContentState` = `checkpointIndex` (1-based), `clue`, `justCleared`. Preview samples: `.preview`, `.searching`, `.cleared`. **Compiled into both targets.** |

### `Quarry/Hunt/` (B)
| File | Contains |
|---|---|
| `HuntSession.swift` | `@Observable final class HuntSession`: `hunt`, `currentIndex`, `startDate`, `isFinished`; computed `checkpoints`, `current`, `progressText`; methods `start()`, `clearCurrent()`, `quit()`. **The only caller of `LiveActivityManager`.** Made `Identifiable` in `ContentView.swift`. |
| `DemoData.swift` | `DemoData.seedIfEmpty(_ context:)`: inserts a 3-checkpoint "Birthday Hunt" (no reference photos yet). |

### `Quarry/Vision/` (A)
| File | Contains |
|---|---|
| `VisionMatcher.swift` | `nonisolated enum VisionMatcher`: `makeReferencePrint(from: UIImage) throws -> Data` · `bestDistance(from: UIImage, to: [Data]) throws -> Float` (smaller = closer) · `score(forDistance:strong:weak:) -> Double` (0…1; **thresholds still need tuning**). Uses `VNGenerateImageFeaturePrintRequest` + `NSKeyedArchiver`. |
| `VerifyCameraView.swift` | `VerifyCameraView(checkpoint:onCleared:)`: real back-camera preview and manual photo capture. Shows the last photo; never calls `onCleared` until Vision verification is implemented. Initializer unchanged. |
| `CameraCaptureView.swift` | `CameraCaptureView(title:message:onCaptured:)` (title/message have defaults): reusable back-camera screen. Returns a `UIImage` on the main actor once per successful shutter tap; stays open for additional photos, caller may dismiss. Close/errors never invoke the callback. Handles permission, Settings, unavailable/interrupted camera, foreground lifecycle, rotation and last-photo preview. Private preview/status views. No Photos or SwiftData image persistence. |
| `CameraSession.swift` | `CameraSession`: serial-queue AVFoundation session configuration, start/stop and still capture; private photo delegate retained through capture completion. Internal implementation for `CameraCaptureView`. |

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
- App Info.plist keys (generated): `NSSupportsLiveActivities = YES`, `NSCameraUsageDescription`.
- Deployment target iOS 26.0. App target uses default MainActor isolation; the extension does not.
- Membership exception: `Shared/HuntActivityAttributes.swift` → also in `QuarryWidgetsExtension`.

## Repo root
| File | Purpose |
|---|---|
| `SPEC.md` | Scope, contracts, work split, timeline, demo, conventions, rules for agents. |
| `MAP.md` | This file. |
| `PLAN.md` | Today's schedule: per-person tasks, agent prompts, merge steps, demo checklist. |
| `AGENTS.md`, `CLAUDE.md` | Point coding agents to `SPEC.md` + `MAP.md`. |
| `README.md` | Quick team overview. |
