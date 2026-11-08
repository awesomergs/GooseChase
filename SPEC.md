# Quarry: Project Spec

**iOSC Fall 2026 Hackathon · Sunday Nov 8 · team of 3 · hacking 10:30am → submit 6:30pm → pitch 7:00pm**

> If you are a coding agent: read this whole file and `MAP.md` before changing code. The "Rules for agents" section is binding.

---

## 1. The pitch in one breath

**Quarry is a scavenger hunt app where the phone is the referee.** A host snaps a couple of photos of hidden things to make a hunt, then shows a QR code; friends scan it to join, phone-to-phone, and everyone starts together. A checkpoint only clears when the camera actually sees the right thing, and a live leaderboard shows who's winning. On-device Vision does the checking, instantly and offline. The hunt's progress and timer live in the Dynamic Island, on the Lock Screen and on the Apple Watch.

**Who it's for:** a club officer running an orientation scavenger hunt. Today 40 freshmen send photos to a group chat and the officer spends an hour checking them. With Quarry, every photo is verified on-device and the leaderboard updates live. No accounts, no internet.

**One-sentence flow:** host shows a QR → friends scan to join → "Start for everyone" → read the clue → point the camera → the ring fills → cleared → the leaderboard updates.

**The moment judges remember:** the confidence ring around the shutter fills as you aim at the right object, then auto-captures with a success haptic. Lock the phone and the hunt is still there on the Lock Screen and in the Dynamic Island, one tap from the camera.

---

## 2. Hackathon constraints (from the guidebook; these decide everything)

- ~8 hours of building. **A small app that fully works beats a big one that half works.** Judges score what it does today.
- Swift/SwiftUI, runs on a real iPhone. **App icon must be made in Icon Composer (no AI-generated icon; it costs points).**
- Pitch = Keynote (~4 slides) + live demo, 3 minutes total: Problem 0:30 · Live demo 1:30 · Why Apple 0:45 · Next 0:15.
- **No server, no accounts.** Local storage only (SwiftData). Multiplayer is **peer-to-peer only** (MultipeerConnectivity, same room) plus AirDrop/Messages file sharing.
- **Free "Personal Team" signing.** No push notifications, no CloudKit, no WeatherKit, no paid capabilities.
- Judging includes **Platform Integration** (why this must be a native app) and **Design** (looks and behaves like Apple's own apps).
- **We're in a basement.** GPS is unreliable indoors, so location is **optional per checkpoint** and never blocks the core camera flow in the demo. Demo Mode skips location checks; launching from Xcode can simulate a location (Debug → Simulate Location).

---

## 3. Scope

### MVP (must work on the phone by 4:00pm)
1. A seeded demo hunt plus the ability to **create a hunt**: add checkpoints with a clue and 2–3 reference photos.
2. **Play a hunt:** clue screen → camera → Vision verifies → cleared screen → next clue → finish screen with total time.
3. **Exact-match verification:** compare camera frames to the reference photos' feature prints, with a live confidence ring and auto-capture.
4. **Live Activity:** Lock Screen + Dynamic Island (compact, minimal, expanded) showing checkpoint X of Y, the clue and an elapsed timer; tapping it (or "Open camera" in the expanded island) jumps straight to the camera. It ends 3 minutes after the hunt finishes.
5. **Apple Watch:** the same Live Activity in the Smart Stack (free via `.supplementalActivityFamilies([.small])`; no Watch app target).
6. **Haptics** on progress, success and error.
7. App icon (Icon Composer), polished with system components and Liquid Glass.
8. **Join a hunt:** the host taps **Host race** → a QR code + 4-letter room code; players scan (in-app, or with the iPhone Camera app via `quarry://join?code=…`) or type the code → the hunt transfers phone-to-phone over MultipeerConnectivity → **"Start for everyone"** starts all phones together after a 3-second countdown.
8b. **Share a hunt as a file** (fallback): ShareLink → AirDrop/Messages → recipient taps the `.quarryhunt` file → "Join <title>?" → imported.
8c. **Live leaderboard:** each clear sends progress to the host, who broadcasts standings to everyone; shown in a sheet during play and on the finish screen.
9. **Guard rails:** a hunt can't start unless every checkpoint is ready (has a reference photo, or a label for object checkpoints); empty hunts can't start.

### Stretch (only after the MVP works on the phone, in this order)
1. **Location (optional per checkpoint):** map pin + radius in the editor, **hot/cold** on the clue screen, optional **"Must be here"** gate; **Demo Mode** skips the gate. (Contract below.)
2. **Rank in the Live Activity** ("2nd of 4").
3. **Object checkpoints:** "find any bicycle" using Vision image classification.
4. **Hints** that add a time penalty.
5. **App Intents:** "Hey Siri, I found it!" / Action button → opens the camera on the current clue; "What's my clue?" → Siri reads it aloud.
6. A **"Make it a riddle" button** that rewrites the clue with Foundation Models (needs iPhone 15 Pro or newer).

### Explicitly out of scope (do not build)
Accounts or login, CloudKit or any backend, joining from outside the room, a Watch app target, Home Screen widgets, onboarding, a settings screen, push notifications, live multiplayer location sharing.

---

## 4. Screens

All screens use stock SwiftUI (`NavigationStack`, `List`, `.toolbar`, `.sheet`, `.fullScreenCover`, `.buttonStyle(.borderedProminent/.glass)`), SF Symbols, Dynamic Type text styles and system colors. Accent = indigo.

| # | Screen | Owner | Contents |
|---|---|---|---|
| 1 | Hunt list (root) | B | `List` of hunts (title, checkpoint count, thumbnail), "+" toolbar button → Create |
| 2 | Create / edit hunt | B | Title field, list of checkpoints (reorderable), "Add checkpoint" |
| 3 | Checkpoint editor | B (+A's components) | Clue text, take 2–3 reference photos, **Test match** button, optional **Location** section (A's `LocationPickerView`: map pin, radius, "Use my location", "Must be here" toggle) |
| 4 | Play: clue | B (+A's component) | "Checkpoint 2 of 5", segmented progress, big clue text, elapsed timer, A's `HotColdView` when the checkpoint has a location, primary **Open camera** button |
| 5 | Camera verify | **A** | Full-screen camera, target chip, **confidence ring around the shutter**, match % text, tip text, auto-capture at threshold |
| 6 | Cleared | B | Captured photo, split time, match %, **Next clue** button, success haptic |
| 7 | Finished | B | Total time, captured photos grid, Done |
| 8 | Live Activity | **C** | Lock Screen, Dynamic Island compact/minimal/expanded, Watch Smart Stack |

The visual mock-ups are on the team design canvas (Quarry iOS Mock-ups). The race and leaderboard screens on it are out of scope.

---

## 5. Code map

See **`MAP.md`** for every file, what it contains, who owns it, and how data flows between them.
Short version: `Quarry/Shared/` = contract, `Quarry/Vision/` = A, `Quarry/Hunt/` + `ContentView.swift` = B,
`Quarry/LiveActivity/` + `QuarryWidgets/` = C.

---

## 6. Contracts between people (keep these stable)

### Data (Shared/Models.swift)
```swift
enum CheckpointKind: String, Codable { case exactMatch, object }

@Model final class Hunt {
    var title: String
    var createdAt: Date
    var shareID: UUID                      // stable across phones; imports dedupe on it; identifies a race
    var hostName: String                   // who made it
    var checkpoints: [Checkpoint]          // cascade delete
    var orderedCheckpoints: [Checkpoint]   // sorted by order
    var isPlayable: Bool                   // has checkpoints AND every checkpoint isReady
}

@Model final class Checkpoint {
    var order: Int
    var clue: String
    var kind: CheckpointKind               // stored as kindRaw
    var referencePrints: [Data]            // archived VNFeaturePrintObservation, one per reference photo
    var thumbnail: Data?                   // small JPEG of the first reference photo
    var targetLabel: String?               // for .object, e.g. "bicycle"
    var hunt: Hunt?
    // Location (optional)
    var latitude: Double?, longitude: Double?
    var coordinate: CLLocationCoordinate2D?   // computed get/set over latitude/longitude
    var radiusMeters: Double               // default 40
    var requiresLocation: Bool             // default false: "Must be here"
    var isReady: Bool                      // exactMatch: has a reference print; object: has a label
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

### Sharing (Shared/HuntPackage.swift, C · conversions by B)
```swift
struct HuntPackage: Codable, Sendable, Transferable { shareID, title, hostName, checkpoints: [CheckpointPackage] }
struct CheckpointPackage: Codable, Sendable { order, clue, kindRaw, referencePrints, thumbnail, targetLabel, latitude, longitude, radiusMeters, requiresLocation }
UTType.quarryHunt                                   // "com.quarryapp.hunt", .quarryhunt (declared in Quarry/Info.plist)
HuntPackage.load(from: URL) throws -> HuntPackage   // decode a received file
// B, in Quarry/Hunt/HuntPackage+SwiftData.swift:
extension HuntPackage { init(hunt: Hunt); @discardableResult func importHunt(into: ModelContext) -> Hunt }  // dedupes by shareID
```

### Race messages (Shared/RaceMessages.swift, C)
```swift
struct PlayerProgress: Codable, Identifiable { id, name, cleared, total, finishedAt: Date?, updatedAt }
enum NearbyMessage: Codable { hello(player:), hunt(HuntPackage), start(at: Date), progress(PlayerProgress), leaderboard([PlayerProgress]) }
enum RoomCode { make() -> String; joinURL(_:) -> URL /* quarry://join?code=KQ7X */; code(from: URL) -> String? }
enum PlayerIdentity { static var id: String; static var name: String }   // persisted in UserDefaults
```

### Nearby (A provides in `Quarry/Nearby/`)
```swift
@Observable @MainActor final class NearbySession {      // NearbySession.shared, serviceType "quarry-hunt"
    var roomCode: String?, isHosting: Bool, connectedPlayers: [String], status: Status
    var receivedHunt: HuntPackage?                     // player: set when the host sends the hunt
    var startAt: Date?                                 // player: set when the host taps Start
    func startHosting(package: HuntPackage) -> String  // returns the room code; sends .hunt to each peer on connect
    func join(code: String)                            // player; sends .hello on connect
    func send(_ message: NearbyMessage)                // host → all; player → host
    func stop()
}   // forwards .hello / .progress / .leaderboard to RaceSession.shared.receive(_:)
    // and on init sets: RaceSession.shared.sendHandler = { [weak self] in self?.send($0) }
struct QRCodeView: View { init(url: URL) }
struct HostLobbyView: View { init(hunt: Hunt, package: HuntPackage, onStart: (Date) -> Void) }   // QR, code, players, "Start for everyone"
struct JoinView: View { init(initialCode: String?, onJoined: (HuntPackage) -> Void) }          // name, code field, QR scanner, waiting state
```

### Race (C provides in `Quarry/Race/`)
```swift
@Observable @MainActor final class RaceSession {        // RaceSession.shared  (BUILT)
    var isActive: Bool, isHost: Bool, huntShareID: UUID?, startDate: Date?
    var players: [PlayerProgress]                      // sorted standings
    var me: PlayerProgress?, myRank: Int?, racerCount: Int, myID: String
    var sendHandler: ((NearbyMessage) -> Void)?        // A's NearbySession sets this; nil = solo play
    func begin(huntShareID: UUID, total: Int, isHost: Bool, startAt: Date = .now)   // keeps lobby hellos
    func reportProgress(cleared: Int, total: Int)      // B's HuntSession calls after each clear
    func receive(_ message: NearbyMessage)             // A's NearbySession forwards race messages
    func rank(of id: String) -> Int?
    func finishTime(of: PlayerProgress) -> TimeInterval?
    func end()                                         // also call before hosting a new race
}
struct LeaderboardView: View { init(race: RaceSession = .shared) }   // (BUILT)
```

### Location (stretch · A provides in `Quarry/Location/`, B embeds)
```swift
@Observable final class LocationService {          // LocationService.shared
    var location: CLLocation?                       // latest fix, nil until authorized
    var demoMode: Bool                              // persisted; skips "Must be here" gates
    func start()                                    // asks When-In-Use permission, starts live updates
    func stop()
    func distance(to: Checkpoint) -> CLLocationDistance?   // nil if no fix or no coordinate
    func isHere(at: Checkpoint) -> Bool                     // true if no requirement, demoMode, or inside radius
}
enum Warmth { case freezing, cold, warm, hot, onFire }  // from distance vs radius; has .label and .color
struct LocationPickerView: View { init(checkpoint: Checkpoint) }   // map pin + radius + "Use my location" + "Must be here"
struct HotColdView: View { init(checkpoint: Checkpoint) }          // distance, direction arrow, warmth band
```
`VerifyCameraView` (A) checks `LocationService.shared.isHere(at:)` before allowing a clear and shows "Get closer: 120 m away" if not.

### Live Activity (C provides, B's HuntSession calls)
```swift
LiveActivityManager.shared.start(huntTitle:totalCheckpoints:firstClue:)
await LiveActivityManager.shared.cleared(index:clue:)    // green "Checkpoint N cleared!" state for ~3 s
await LiveActivityManager.shared.advance(to:clue:)
await LiveActivityManager.shared.end(finalMessage:)
await LiveActivityManager.shared.endAllStale()           // on launch, clears leftovers
```
`HuntSession` already calls these. Tapping the Live Activity opens `quarry://camera`, handled by `.onOpenURL` in the play screen.

---

## 7. Work split and acceptance criteria

See **`PLAN.md`**: it holds the current per-person tasks, acceptance checks, agent prompts and timeline. It's updated as the day goes; this file holds what doesn't change (scope, contracts, conventions).

---

## 8. Timeline

See **`PLAN.md`**. Fixed points: **4:00 Merge 2 · 5:30 feature freeze · 6:15 submit on Devpost · 6:30 deadline · 7:00 pitch.**

---

## 9. Demo script (1:30 live)

1. "Here's a hunt I made for my niece's party." Open the hunt and tap **Start**. *The Dynamic Island appears with "1/3" and a ticking timer.*
2. Read the clue aloud. Lock the phone briefly. *The Lock Screen shows the clue and progress.*
3. Unlock, tap **Open camera**, and point at a wrong object. *The ring stays low.*
4. Point at the right object. *The ring fills, auto-captures, buzz, "Cleared!"* Go Home: *the island now shows 2/3.* Long-press the island → **Open camera** jumps straight back in.
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
8. **If you add, rename or delete a file, or change a public type or function, update `MAP.md` in the same change.**
