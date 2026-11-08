# Quarry: Project Spec

**iOSC Fall 2026 Hackathon · Sunday Nov 8 · team of 3 · hacking 10:30am → submit 6:30pm → pitch 7:00pm**

> If you are a coding agent: read this whole file before changing code. The "Rules for agents" section is binding.

---

## 1. The pitch in one breath

**Quarry is a scavenger hunt app where the phone is the referee.** A host snaps a couple of photos of hidden things to make a hunt. Players get clues, and a checkpoint only clears when the camera actually sees the right thing. On-device Vision does the checking, instantly and offline. The hunt's progress and timer live in the Dynamic Island, on the Lock Screen and on the Apple Watch.

**Who it's for:** a parent running an indoor scavenger hunt at a kid's birthday party, who's tired of refereeing "did you *really* find it?" One phone, no accounts, no internet.

**One-sentence flow:** pick a hunt → read the clue → find the thing → point the camera → the ring fills → cleared → next clue.

**The moment judges remember:** the confidence ring around the shutter fills as you aim at the right object, then auto-captures with a success haptic, and the Dynamic Island pops open saying "Checkpoint cleared!"

---

## 2. Hackathon constraints (from the guidebook; these decide everything)

- ~8 hours of building. **A small app that fully works beats a big one that half works.** Judges score what it does today.
- Swift/SwiftUI, runs on a real iPhone. **App icon must be made in Icon Composer (no AI-generated icon; it costs points).**
- Pitch = Keynote (~4 slides) + live demo, 3 minutes total: Problem 0:30 · Live demo 1:30 · Why Apple 0:45 · Next 0:15.
- **No server, no accounts, no social/multiplayer.** Local storage only (SwiftData).
- **Free "Personal Team" signing.** No push notifications, no CloudKit, no WeatherKit, no paid capabilities.
- Judging includes **Platform Integration** (why this must be a native app) and **Design** (looks and behaves like Apple's own apps).
- **We're in a basement.** GPS is unreliable, so nothing in the core flow depends on location.

---

## 3. Scope

### MVP (must work on the phone by 4:00pm)
1. A seeded demo hunt plus the ability to **create a hunt**: add checkpoints with a clue and 2–3 reference photos.
2. **Play a hunt:** clue screen → camera → Vision verifies → cleared screen → next clue → finish screen with total time.
3. **Exact-match verification:** compare camera frames to the reference photos' feature prints, with a live confidence ring and auto-capture.
4. **Live Activity:** Lock Screen + Dynamic Island (compact, minimal, expanded) showing checkpoint X of Y, the clue and an elapsed timer; it pops open on clear.
5. **Apple Watch:** the same Live Activity in the Smart Stack (free via `.supplementalActivityFamilies([.small])`; no Watch app target).
6. **Haptics** on progress, success and error.
7. App icon (Icon Composer), polished with system components and Liquid Glass.

### Stretch (only after the MVP works on the phone, in this order)
1. **Object checkpoints:** "find any bicycle" using Vision image classification.
2. **Hints** that add a time penalty.
3. An **App Intent** button inside the Live Activity ("Open camera").
4. A **"Make it a riddle" button** that rewrites the clue with Foundation Models (needs iPhone 15 Pro or newer).

### Explicitly out of scope (do not build)
Live races, leaderboards, accounts or login, CloudKit or any backend, a Watch app target, Home Screen widgets, onboarding, a settings screen, location-gated checkpoints, push notifications.

---

## 4. Screens

All screens use stock SwiftUI (`NavigationStack`, `List`, `.toolbar`, `.sheet`, `.fullScreenCover`, `.buttonStyle(.borderedProminent/.glass)`), SF Symbols, Dynamic Type text styles and system colors. Accent = indigo.

| # | Screen | Owner | Contents |
|---|---|---|---|
| 1 | Hunt list (root) | B | `List` of hunts (title, checkpoint count, thumbnail), "+" toolbar button → Create |
| 2 | Create / edit hunt | B | Title field, list of checkpoints (reorderable), "Add checkpoint" |
| 3 | Checkpoint editor | B (+A's capture) | Clue text, take 2–3 reference photos, **Test match** button showing the live score, Save |
| 4 | Play: clue | B | "Checkpoint 2 of 5", segmented progress, big clue text, elapsed timer, primary **Open camera** button |
| 5 | Camera verify | **A** | Full-screen camera, target chip, **confidence ring around the shutter**, match % text, tip text, auto-capture at threshold |
| 6 | Cleared | B | Captured photo, split time, match %, **Next clue** button, success haptic |
| 7 | Finished | B | Total time, captured photos grid, Done |
| 8 | Live Activity | **C** | Lock Screen, Dynamic Island compact/minimal/expanded, Watch Smart Stack |

The visual mock-ups are on the team design canvas (Quarry iOS Mock-ups). The race, leaderboard and map screens on it are out of scope.

---

## 5. Code map (what exists right now)

```
Quarry/
├── QuarryApp.swift              App entry, SwiftData container [Hunt, Checkpoint]
├── ContentView.swift            (B) Temporary root: hunt list + PlayView. Replace freely.
├── Shared/                      CONTRACT: change only after telling the team
│   ├── Models.swift             Hunt, Checkpoint, CheckpointKind (SwiftData @Model)
│   └── HuntActivityAttributes.swift   Live Activity data (compiled into app AND widget extension)
├── Hunt/                        (B)
│   ├── HuntSession.swift        @Observable: current checkpoint, start/clearCurrent/quit → drives Live Activity
│   └── DemoData.swift           Seeds a 3-checkpoint "Birthday Hunt" if the store is empty
├── Vision/                      (A)
│   ├── VisionMatcher.swift      makeReferencePrint(from:), bestDistance(from:to:), score(forDistance:)
│   └── VerifyCameraView.swift   STUB with a "Pretend cleared" button. A replaces the body.
└── LiveActivity/                (C)
    └── LiveActivityManager.swift   start / cleared / advance / end / endAllStale
QuarryWidgets/                   (C) Widget extension target "QuarryWidgetsExtension"
├── QuarryWidgetsBundle.swift    Bundle body = HuntLiveActivity() only
└── QuarryWidgetsLiveActivity.swift   Lock Screen, Dynamic Island, Watch (.small) layouts + previews
```

`Item.swift`, `QuarryWidgets.swift` and `QuarryWidgetsControl.swift` are empty placeholders and can be deleted.

---

## 6. Contracts between people (keep these stable)

### Data (Shared/Models.swift)
```swift
enum CheckpointKind: String, Codable { case exactMatch, object }

@Model final class Hunt {
    var title: String
    var createdAt: Date
    var checkpoints: [Checkpoint]          // cascade delete
    var orderedCheckpoints: [Checkpoint]   // sorted by order
}

@Model final class Checkpoint {
    var order: Int
    var clue: String
    var kind: CheckpointKind               // stored as kindRaw
    var referencePrints: [Data]            // archived VNFeaturePrintObservation, one per reference photo
    var thumbnail: Data?                   // small JPEG of the first reference photo
    var targetLabel: String?               // for .object, e.g. "bicycle"
    var hunt: Hunt?
}
```

### Camera (A provides, B calls)
```swift
VerifyCameraView(checkpoint: Checkpoint, onCleared: () -> Void)
```
- Calls `onCleared()` exactly once, after auto-capture succeeds. B dismisses the view and calls `session.clearCurrent()`.
- **Keep this initializer.** You may add an optional `onCaptured: (UIImage, Double) -> Void` later for the cleared screen's photo and score; tell B first.

### Vision helpers (A provides, B uses in the checkpoint editor)
```swift
VisionMatcher.makeReferencePrint(from: UIImage) throws -> Data
VisionMatcher.bestDistance(from: UIImage, to: [Data]) throws -> Float   // smaller = more similar
VisionMatcher.score(forDistance: Float) -> Double                       // 0...1 for the ring
```

### Live Activity (C provides, B's HuntSession calls)
```swift
LiveActivityManager.shared.start(huntTitle:totalCheckpoints:firstClue:)
await LiveActivityManager.shared.cleared(index:clue:)    // pops the island open with an alert
await LiveActivityManager.shared.advance(to:clue:)
await LiveActivityManager.shared.end(finalMessage:)
await LiveActivityManager.shared.endAllStale()           // on launch, clears leftovers
```
`HuntSession` already calls these. Tapping the Live Activity opens `quarry://camera`, handled by `.onOpenURL` in the play screen.

---

## 7. Work split and acceptance criteria

### Person A: Camera + Vision (`Quarry/Vision/`)
Build the real `VerifyCameraView`:
- [ ] AVFoundation camera preview, full screen, back camera.
- [ ] Sample frames about 5 times a second (not every frame); compute `bestDistance` → `score` off the main thread.
- [ ] Confidence ring around the shutter button that animates to the current score. Color: neutral → yellow (≥50%) → green (≥ threshold).
- [ ] Auto-capture when the score stays ≥ the threshold for ~0.5 s. Success haptic (`.sensoryFeedback(.success, …)`), then `onCleared()`.
- [ ] Manual shutter as a fallback: if the score is below the threshold, show "Not quite. Try another angle" with an error haptic.
- [ ] "Match 72%" label plus a one-line tip.
- [ ] **Tune thresholds** in `VisionMatcher.score` by testing 5+ real objects in the room (same object should pass; similar-looking wrong objects should fail). Write the chosen numbers in a comment.
- [ ] Provide a small reusable camera-capture view for B's checkpoint editor (take a still photo → `UIImage`).
- Stretch: `.object` checkpoints with `VNClassifyImageRequest` (pass when `targetLabel` confidence ≥ 0.3).

Done when: on the phone, pointing at the reference object fills the ring and clears within ~2 s, and pointing at a different object does not.

### Person B: Hunt flow + data (`Quarry/Hunt/`, `ContentView.swift`)
- [ ] Hunt list with thumbnails; swipe to delete.
- [ ] Create hunt → checkpoint editor: clue field, capture 2–3 reference photos (A's capture view, or `PhotosPicker` as a temporary stand-in), store prints via `makeReferencePrint`, store a downsized JPEG thumbnail.
- [ ] **Test match** button in the editor: opens `VerifyCameraView` for that checkpoint so the host can confirm it works.
- [ ] Play flow polish: progress segments, elapsed timer, cleared screen with split time, finished screen with total time.
- [ ] Haptics on navigation milestones (`.sensoryFeedback`).
- [ ] Keep `HuntSession` as the single place that calls `LiveActivityManager`.

Done when: you can create a 3-checkpoint hunt from scratch on the phone and play it start to finish.

### Person C (Rohan): Platform + pitch (`Quarry/LiveActivity/`, `QuarryWidgets/`)
- [ ] Live Activity verified on a real phone: compact, minimal, expanded, Lock Screen; alert pop on clear.
- [ ] Watch Smart Stack layout verified (if someone has an Apple Watch on watchOS 11+).
- [ ] Polish the island: SF Symbols, indigo keyline, readable timer width.
- [ ] Owns all project settings, targets and capabilities (`project.pbxproj`).
- [ ] App icon in Icon Composer (20 min budget): a simple SF Symbol (`viewfinder` or `scope`) on an indigo gradient.
- [ ] Keynote deck (4 slides) + demo script rehearsal by 6:30.
- Stretch: App Intent "Open camera" button in the expanded island.

Done when: starting the demo hunt shows the island within 1 s; clearing a checkpoint pops it open with "Checkpoint cleared!"

---

## 8. Timeline

| Time | Milestone (guidebook checkpoint) |
|---|---|
| 11:00 | Idea locked, skeleton builds on every laptop, runs on one iPhone |
| 1:00 | **Merge 1.** Core flow works on the phone: real camera replaces the stub; Live Activity starts and ends |
| 4:00 | **Merge 2.** Create flow works; ring + auto-capture tuned; island polished; icon done |
| 5:30 | **Feature freeze.** Bug fixes only. C builds the Keynote; A and B rehearse the demo |
| 6:30 | Submit GitHub repo + Keynote on Devpost |
| 7:00 | Pitch |

**If behind, cut in this order:** Object checkpoints → App Intent button → hints → create flow (hard-code the demo hunt and take reference photos in the room). **Never cut** the camera ring or the Live Activity.

---

## 9. Demo script (1:30 live)

1. "Here's a hunt I made for my niece's party." Open the hunt and tap **Start**. *The Dynamic Island appears with "1/3" and a ticking timer.*
2. Read the clue aloud. Lock the phone briefly. *The Lock Screen shows the clue and progress.*
3. Unlock, tap **Open camera**, and point at a wrong object. *The ring stays low.*
4. Point at the right object. *The ring fills, auto-captures, buzz, "Cleared!"; the island pops open.*
5. Show the watch: same progress on the wrist.
6. (If time) Create a new checkpoint live: snap 2 photos of a judge's water bottle, tap **Test match**.

**Backup:** demo on the Simulator if the phone fails. Before the pitch, charge the phone, turn on Do Not Disturb, set Auto-Lock to Never, and pre-seed the demo hunt with reference photos of objects that will be on stage.

## 10. Keynote (4 slides)
1. **Problem:** the party-host story; refereeing kids' "I found it!" claims.
2. **Live demo:** (switch to the phone).
3. **Why it's an Apple app:** on-device Vision (private, offline, instant), Live Activity + Dynamic Island, Apple Watch Smart Stack, haptics, Liquid Glass.
4. **Next:** Object checkpoints for "find anything red" hunts, or AI-written riddles with Foundation Models.

---

## 11. Engineering conventions

- **Platform:** iOS 26 deployment target, Xcode 26/27, Swift 5 language mode with **default MainActor isolation** and approachable concurrency turned on.
  - Heavy work (Vision) must be `nonisolated` or run in a `Task.detached`. Never block the main thread with per-frame work.
  - Types shared with the widget extension are marked `nonisolated` (the extension doesn't use default MainActor isolation).
- **State:** `@Observable` classes and `@State`/`@Bindable`. No `ObservableObject`/`@Published` unless needed.
- **Persistence:** SwiftData only. Use `@Query` in views and `modelContext.insert` / `save`.
- **Images:** never store full-size photos in SwiftData. Store feature prints plus a ≤300 px JPEG thumbnail (`@Attribute(.externalStorage)`).
- **UI:** system components first, so they get Liquid Glass automatically. Liquid Glass is for **controls** (toolbars, tab bars, floating buttons), never for content cards or backgrounds. Use `.glass` / `.glassProminent` button styles sparingly. SF Symbols only, no custom icon images. Dynamic Type text styles (`.title2`, `.headline`), not fixed font sizes.
- **Haptics:** `.sensoryFeedback(.success / .error / .increase, trigger:)`.
- **Accessibility:** buttons have labels; icon-only buttons get `.accessibilityLabel`.
- **Errors:** never `fatalError` in feature code. Show a short inline message and log with `print("⚠️ …")`.
- **Previews:** every new view gets a `#Preview` using an in-memory model container.

## 12. Git workflow

- Branches: `vision` (A), `hunt` (B), `live-activity` (C). Merge into `main` at 1:00, 4:00 and 5:30. Pull `main` into your branch after each merge.
- **Only edit files in your own folders.** `Shared/` changes need a heads-up in the team chat.
- **Only Rohan (C) edits `project.pbxproj`:** targets, capabilities, Info.plist keys, build settings. Ask C if you need a permission string or capability.
- Set Signing Team locally and **don't commit signing changes.**
- Commit before asking an agent for a big change.

---

## 13. Rules for agents (binding)

1. **Stay in your owner's folder.** Don't edit another person's folder, `Shared/`, or `project.pbxproj` unless the human explicitly asks.
2. **Don't change the contracts in section 6** (initializers, function signatures, model properties) without being told to. Add, don't rename.
3. **No new dependencies:** no Swift packages, no backends, no network calls, no paid capabilities (push, CloudKit, App Groups requiring provisioning).
4. **Don't add out-of-scope features** (section 3).
5. Build after every change and fix all errors before reporting done. Don't claim something works without saying it was built.
6. Prefer the simplest code that works today. This is an 8-hour hackathon; no abstractions "for later."
7. When you finish a change, explain it in 2–3 plain sentences so the human can explain it to judges.
