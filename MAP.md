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

- **Play:** `ContentView` → creates `HuntSession(hunt:)` → `session.start()` → `LiveActivityManager.start` → `PlayView` shows the clue → `VerifyCameraView` → `onCleared` → `session.clearCurrent()` (records the split, `LiveActivityManager.cleared`, arms a 3s auto-advance) → `CheckpointClearedView` → "Next clue"/"Finish" (or the timer) → `session.advance()` (`advance` or `end`, runs once per checkpoint) → `HuntFinishedView`.
- **Create:** checkpoint editor → photo `UIImage` → `VisionMatcher.makeReferencePrint` → stored in `Checkpoint.referencePrints`.
- **Verify:** camera frame → `VisionMatcher.bestDistance(from:to:)` → `VisionMatcher.score(forDistance:)` → ring progress → auto-capture → `onCleared()`.
- **Deep link:** tapping the Live Activity → `quarry://camera` → `.onOpenURL` in `PlayView` → opens the camera.

## Files

### `Quarry/` (app root)
| File | Owner | Contains |
|---|---|---|
| `QuarryApp.swift` | C | `@main QuarryApp`: SwiftData `ModelContainer` with schema `[Hunt, Checkpoint]`. |
| `ContentView.swift` | B | `ContentView` (`NavigationStack(path: NavigationPath)` hunt list with first-checkpoint thumbnail, "+" creates a `Hunt` and pushes `HuntEditorView`, per-row Edit/Delete swipe actions; seeds demo data, ends stale Live Activities on launch; registers `navigationDestination` for both `Hunt` and `Checkpoint`; presents `PlayView` via `.fullScreenCover(item:)`). `PlayView` now lives in `Hunt/PlayView.swift`. |
| `Item.swift` | n/a | Empty placeholder. Delete. |

### `Quarry/Shared/` (contract; change only after telling the team)
| File | Contains |
|---|---|
| `Models.swift` | `enum CheckpointKind { exactMatch, object }` · `@Model Hunt` (`title`, `createdAt`, `checkpoints`, computed `orderedCheckpoints`) · `@Model Checkpoint` (`order`, `clue`, `kindRaw` + computed `kind`, `referencePrints: [Data]`, `thumbnail: Data?`, `targetLabel: String?`, `hunt`). |
| `HuntActivityAttributes.swift` | `nonisolated struct HuntActivityAttributes: ActivityAttributes`: fixed `huntTitle`, `totalCheckpoints`, `startDate`; `ContentState` = `checkpointIndex` (1-based), `clue`, `justCleared`. Preview samples: `.preview`, `.searching`, `.cleared`. **Compiled into both targets.** |

### `Quarry/Hunt/` (B)
| File | Contains |
|---|---|
| `HuntSession.swift` | `@Observable final class HuntSession`: `hunt`, `currentIndex`, `startDate`, `isFinished`, `splits: [TimeInterval]`, `lastClearedNumber`, `isAwaitingAdvance`; computed `checkpoints`, `current`, `progressText`, `lastSplit`, `totalTime`; methods `start()`, `clearCurrent()` (records the split + `LiveActivityManager.cleared` + arms a 3s auto-advance; does **not** advance), `advance()` (moves to the next checkpoint or finishes; guarded by `isAwaitingAdvance` so the button and timer run it once), `quit()` (cancels the timer + ends). **The only caller of `LiveActivityManager`.** Made `Identifiable` in `Hunt/PlayView.swift`. |
| `PlayView.swift` | `PlayView(session:onClose:)`: custom top bar (xmark End + running `.timer`), segmented capsule progress bar (cleared/current/upcoming), "Checkpoint N of M", clue card, large "Open camera" button; presents `VerifyCameraView`, handles `quarry://camera`, success haptic. Shows `CheckpointClearedView` (green check, "Checkpoint N cleared!", split time, "Next clue"/"Finish" → `session.advance()`) while `isAwaitingAdvance`, and `HuntFinishedView` ("Hunt complete!", total time, thumbnail grid, Done) when `isFinished`. Holds `extension HuntSession: Identifiable`. |
| `DemoData.swift` | `DemoData.seedIfEmpty(_ context:)`: inserts a 3-checkpoint "Birthday Hunt" (no reference photos yet). |
| `HuntEditorView.swift` | `HuntEditorView(hunt:path:)`: `Form` to edit a `Hunt`'s title and list its `orderedCheckpoints` (clue + thumbnail). "Add checkpoint" creates a `Checkpoint` with the next `order` and pushes `CheckpointEditorView` by appending to the shared `NavigationPath`; swipe to delete (renormalizes `order`); drag to reorder (`EditButton`); deletes the hunt on exit if it's still an untouched "New Hunt". |
| `CameraPicker.swift` | `CameraPicker(onImage:)`: `UIViewControllerRepresentable` wrapping `UIImagePickerController`; uses `.camera` on device, falls back to `.photoLibrary` in Simulator. Calls `onImage` then dismisses via `@Environment(\.dismiss)`. |
| `CheckpointEditorView.swift` | `CheckpointEditorView(checkpoint:)`: `Form` with a clue `TextField` and a "Reference photos" section showing up to 3 thumbnails. Presents `CameraPicker`, calls `VisionMatcher.makeReferencePrint` on a detached background `Task`, appends to `checkpoint.referencePrints`, and stores a ≤300 px JPEG thumbnail. Shows `ProgressView` while processing and an inline red error on failure. |

### `Quarry/Vision/` (A)
| File | Contains |
|---|---|
| `VisionMatcher.swift` | `nonisolated enum VisionMatcher`: `makeReferencePrint(from: UIImage) throws -> Data` · `bestDistance(from: UIImage, to: [Data]) throws -> Float` (smaller = closer) · `score(forDistance:strong:weak:) -> Double` (0…1; **thresholds still need tuning**). Uses `VNGenerateImageFeaturePrintRequest` + `NSKeyedArchiver`. |
| `VerifyCameraView.swift` | `VerifyCameraView(checkpoint:onCleared:)`. **Currently a stub** with a "Pretend cleared" button. A replaces the body; the initializer stays the same. |

### `Quarry/LiveActivity/` (C)
| File | Contains |
|---|---|
| `LiveActivityManager.swift` | `@MainActor final class LiveActivityManager`, `.shared`: `start(huntTitle:totalCheckpoints:firstClue:)` · `cleared(index:clue:) async` (alert pops the island) · `advance(to:clue:) async` · `end(finalMessage:) async` · `endAllStale() async`. Local updates only, no push. |

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
| `AGENTS.md`, `CLAUDE.md` | Point coding agents to `SPEC.md` + `MAP.md`. |
| `README.md` | Quick team overview. |
