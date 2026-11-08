# Quarry: Afternoon Plan (v3, rebuilt 1:05): Joining + Live Leaderboard

**The new headline feature:** a host makes a hunt, shows a **QR code / 4-letter room code**, friends **scan to join** (phone-to-phone, no internet), the host taps **Start for everyone**, and a **live leaderboard** updates as people clear checkpoints. **AirDrop/Messages sharing** of a hunt file is the fallback. **Location is now a stretch goal.**

**Story for the pitch:** our club's orientation scavenger hunt. 40 freshmen sent photos to a group chat and an officer spent an hour checking them. Quarry checks every photo on-device and shows who's winning live.

**Fixed times:** 1:20 sync · **4:00 Merge 2** · **5:30 feature freeze** · **6:15 submit on Devpost** · 6:30 deadline · 7:00 pitch.

| Person | Owns | This afternoon |
|---|---|---|
| **A** | `Quarry/Vision/`, **new** `Quarry/Nearby/` | Nearby connection (MultipeerConnectivity), QR show + scan, Host lobby + Join screens |
| **B** | `Quarry/Hunt/`, `ContentView.swift` | Guard rails, hunt ⇄ package conversion, AirDrop share + import, wiring Host/Join/Start into the flow, Cleared/Finished screens |
| **C** (Rohan) | `Shared/`, **new** `Quarry/Race/`, `Quarry/LiveActivity/`, `QuarryWidgets/`, project settings | Shared contract (done), RaceSession + Leaderboard, merges, name + icon, Keynote |

Contracts for all of this are in **`SPEC.md` section 6**. Read it before starting.

---

## How the pieces connect

```
HOST PHONE                                      PLAYER PHONE
Hunt ──B: HuntPackage(hunt:)──▶ A: NearbySession.startHosting(package:) ──▶ shows QR + code (A: HostLobbyView)
                                                      ▲ player scans QR / types code (A: JoinView)
                                     connection ◀─────┘  A: NearbySession.join(code:)
A sends .hunt(package) ──────────────────────────────▶ A: receivedHunt → B imports it into SwiftData
Host taps "Start for everyone" → .start(at:) ────────▶ A: startAt → B starts HuntSession at that time
B: HuntSession.clearCurrent → C: RaceSession.reportProgress ─▶ .progress ─▶ host RaceSession merges
host RaceSession ── .leaderboard([...]) ──▶ every phone → C: LeaderboardView shows live standings
```

---

## At a glance

| Time | A | B | C (Rohan) |
|---|---|---|---|
| 1:05–1:20 | Finish A1 tuning (if started) | **B1** Guard rails (start now) | **C1** Build, commit shared contract + settings, merge to `main` |
| **1:20** | **Everyone pulls `main`** (5-min sync) | | |
| 1:20–2:30 | **A2** `NearbySession` (connect, send, receive) | **B2** `HuntPackage` ⇄ SwiftData + AirDrop share/import | **C2** `RaceSession` + `LeaderboardView` |
| 2:30–3:30 | **A3** QR + scanner + `HostLobbyView` + `JoinView` | **B3** Wire Host / Join / synced Start / leaderboard into the flow | **C3** Name + icon · test joining on 2 phones with A |
| 3:30–4:00 | **A4** Reliability (reconnects, errors) | **B4** Cleared + Finished screens (with leaderboard) | **C4** Live Activity shows rank (stretch) |
| **4:00** | **Merge 2**, then a 3-phone test (everyone) | | |
| 4:00–5:30 | Bugs; stretch: location | Polish + edge cases | Keynote + screenshots + demo prep |
| **5:30** | **Feature freeze** | | |
| 5:30–6:15 | Demo rehearsal with 3 phones | | Final merge → build → **submit by 6:15** |

**Testing needs 2 real phones** (MultipeerConnectivity doesn't connect two Simulators reliably). Pair up: A + Rohan test joining from ~2:45.

---

## Working rules
- Branch per person; **only Rohan merges into `main`**.
- **Untick `project.pbxproj` when committing** (signing IDs). Only Rohan commits project-file changes.
- Stash in Xcode → **always tick "Apply Stash After Operation."**
- Only edit your own folders. `Shared/` is Rohan's; ask before changing it.
- Start every agent chat with: *"Read AGENTS.md, SPEC.md, MAP.md and PLAN.md. I am Person [A/B/C]."*
- Update `MAP.md` in the same commit when adding files or changing public types.

---

## Person C (Rohan)

### C1 · now–1:20 · Ship the shared contract
Already written into your folder by Claude:
- `Shared/Models.swift`: `Hunt.shareID`, `Hunt.hostName`, `Hunt.isPlayable`, `Checkpoint.isReady`, and the location fields.
- `Shared/HuntPackage.swift`: `HuntPackage`/`CheckpointPackage` (Codable, Transferable), `UTType.quarryHunt`.
- `Shared/RaceMessages.swift`: `NearbyMessage`, `PlayerProgress`, `RoomCode`, `PlayerIdentity`.
- `Quarry/Info.plist` (new) + project settings: the `quarry://` URL scheme (so the iPhone Camera app can open join QR codes), local-network permission + Bonjour service `_quarry-hunt._tcp`, the `.quarryhunt` file type, plus the location permission.

Steps: if Xcode asks, **Use Version on Disk** → ⌘B → ⌘R on your phone (old hunts must still load) → commit **including `project.pbxproj` this time** (but re-check that only your own signing team is in it) → merge into `main` → push → tell A and B: **"Pull main now."**

### C2 · 1:20–2:30 · RaceSession + LeaderboardView (`Quarry/Race/`)
> /plan Read SPEC.md section 6 (Race contract) and Shared/RaceMessages.swift. Create Quarry/Race/RaceSession.swift: `@Observable @MainActor final class RaceSession` with `static let shared`. State: `isActive`, `isHost`, `huntShareID: UUID?`, `players: [PlayerProgress]` (sorted: finished first by finishedAt, then by cleared desc, then updatedAt asc). Methods: `begin(huntShareID:total:isHost:)` adds this phone (PlayerIdentity.id/name) with cleared 0; `reportProgress(cleared:total:)` updates this phone's entry (finishedAt when cleared == total), then if host: broadcast `.leaderboard(players)` via `NearbySession.shared.send(_:)`, else send `.progress(me)`; `receive(_ message: NearbyMessage)`: host merges `.hello`/`.progress` into players and broadcasts `.leaderboard`; players replace `players` on `.leaderboard`; `end()`. Expose `rank(of id: String) -> Int?`. Then Quarry/Race/LeaderboardView.swift: a List of players with rank number (gold for 1st), name ("You" for this phone, bold), a segmented progress bar of cleared/total, and the finish time or "3 of 5"; animate reordering; .sensoryFeedback(.selection) when your rank changes. Add #Previews with fake players. Until A's NearbySession exists, call it through a tiny protocol or comment out the send lines. Update MAP.md.

### C3 · 2:30–3:30 · Name + icon, and the first 2-phone join test with A
- Pick the name by **2:45**. Claude updates the display name and copy.
- Icon in Icon Composer (not AI) → `AppIcon` → Target → General → App Icon.
- With A: host on your phone, join from A's phone, confirm the hunt arrives and the leaderboard moves.

### C4 · 3:30–4:00 · Stretch: rank in the Live Activity
Add `rank: Int?` and `racers: Int?` to `HuntActivityAttributes.ContentState` (tell the team; Shared change), show "2nd of 4" in the expanded island and on the Lock Screen, update from RaceSession when standings change.

### C5 · 4:00–5:30 · Merge 2, 3-phone test, Keynote, demo prep
Merge B, then A, then yours → build → **3-phone test** (host + 2 joiners) → push. Then Keynote (Claude drafts the text). Build the final demo hunt with objects that will be on stage.

---

## Person A · Nearby connection + QR

**Pull `main` at 1:20 first.** Read `SPEC.md` section 6 (Nearby contract) and `Shared/RaceMessages.swift`.

### A2 · 1:20–2:30 · NearbySession (`Quarry/Nearby/NearbySession.swift`)
> /plan Create Quarry/Nearby/NearbySession.swift: `@Observable @MainActor final class NearbySession` with `static let shared`, built on MultipeerConnectivity with serviceType "quarry-hunt" (matches NSBonjourServices in Info.plist). MCPeerID displayName = PlayerIdentity.name. State: `roomCode: String?`, `isHosting: Bool`, `connectedPlayers: [String]` (display names), `status: Status` (.idle, .hosting, .searching, .connected, .failed(String)), `receivedHunt: HuntPackage?`, `startAt: Date?`. Host: `startHosting(package: HuntPackage) -> String` makes a RoomCode, advertises with discoveryInfo ["code": code], auto-accepts invitations, and when a peer connects sends `.hunt(package)` to that peer. Player: `join(code: String)` browses, invites the first peer whose discoveryInfo code matches, and on connect sends `.hello(player:)` with PlayerIdentity and cleared 0. `send(_ message: NearbyMessage)`: host → all connected peers, player → host; use .reliable. Receiving: decode NearbyMessage; `.hunt` → set receivedHunt; `.start(at:)` → set startAt; `.hello`, `.progress`, `.leaderboard` → forward to RaceSession.shared.receive(_:) (C is building it; if it doesn't exist yet, leave a TODO and print). Do all MC delegate callbacks off-main and hop to the main actor to mutate state. `stop()` disconnects and clears state. Update MAP.md.

✅ Check (needs 2 phones, pair with Rohan ~2:45): host on one, `join(code:)` on the other, the second phone receives the hunt.

### A3 · 2:30–3:30 · QR + scanner + Host lobby + Join screens
> /plan In Quarry/Nearby/: (1) `QRCodeView(url: URL)`: renders a QR with CoreImage CIFilter.qrCodeGenerator, crisp (interpolation .none), white background, rounded. (2) `HostLobbyView(hunt: Hunt, package: HuntPackage, onStart: (Date) -> Void)`: calls NearbySession.shared.startHosting(package:) on appear, shows the hunt title, a big QRCodeView(url: RoomCode.joinURL(code)), the room code in large monospaced letters, a live list of connectedPlayers ("Maya joined" with a checkmark and a light haptic per join), and a prominent "Start for everyone" button (disabled with 0 players) that sends `.start(at: now + 3 s)` and calls onStart(date). Stop hosting on Cancel. (3) `JoinView(initialCode: String?, onJoined: (HuntPackage) -> Void)`: a name field bound to PlayerIdentity.name, a 4-character code field (auto-uppercase, joins automatically at 4 chars), and a "Scan QR" button that opens a scanner (VisionKit DataScannerViewController for .barcode(symbologies: [.qr]) wrapped in UIViewControllerRepresentable, or the existing camera session with AVCaptureMetadataOutput) which extracts the code with RoomCode.code(from:). Show "Connecting…", then "Joined <title> · <n> checkpoints · hosted by <name>. Waiting for the host to start…" and call onJoined when receivedHunt arrives. Add #Previews. Update MAP.md.

### A4 · 3:30–4:00 · Reliability
> /plan Harden NearbySession: handle a peer disconnecting (remove from connectedPlayers), a player re-joining with the same name, a wrong code (time out after 10 s with "No hunt found with code KQ7X"), and local-network permission denied (show a helpful message in JoinView pointing to Settings). Make sure the host keeps advertising while the lobby is open and stops after Start is sent + 30 s.

### Stretch (after Merge 2): Location
Previous plan v2 tasks A2–A4 (LocationService, LocationPickerView, HotColdView, "Must be here" gate). Only if joining is solid.

---

## Person B · Hunt flow

### B1 · now–1:20 · Guard rails + camera-sheet fix
> /plan Fix these in ContentView/PlayView/HuntEditorView: (1) Tapping a hunt that isn't playable (Hunt.isPlayable is false; pull main first, it's new) must not start it: show an alert "Finish setting up this hunt" with an "Edit" button that pushes HuntEditorView. Show a small "Needs photos" caption on unplayable hunt rows. (2) In HuntEditorView, mark checkpoints where isReady is false with an orange exclamation icon. (3) In PlayView, store the checkpoint the camera was opened for in @State (`cameraCheckpoint: Checkpoint?`) and present the camera with .fullScreenCover(item:) on it, so the sheet never switches to the next checkpoint while dismissing. (4) The .onOpenURL handler should set cameraCheckpoint = session.current. Don't edit Shared/ or Vision/.

(`isPlayable` arrives when Rohan pushes `main` at ~1:20; write the rest first.)

### B2 · 1:20–2:30 · Hunt ⇄ package + AirDrop sharing + import
> /plan Read SPEC.md section 6 and Shared/HuntPackage.swift. Create Quarry/Hunt/HuntPackage+SwiftData.swift with `extension HuntPackage { init(hunt: Hunt) }` (copies everything, including referencePrints, thumbnails, location fields, shareID, hostName) and `@discardableResult func importHunt(into context: ModelContext) -> Hunt` that finds an existing Hunt with the same shareID (FetchDescriptor with #Predicate) and replaces its title and checkpoints, or inserts a new one. In ContentView: add a "Share" swipe action / context menu on playable hunts using ShareLink(item: HuntPackage(hunt:), preview: SharePreview(hunt.title, image: Image(systemName: "flag.fill"))) so it can go by AirDrop or Messages. Handle incoming files in .onOpenURL: if url.isFileURL, try HuntPackage.load(from:), then show a confirmation sheet "Join <title>? <n> checkpoints · from <hostName>" with Join (imports, then shows it in the list) and Cancel. When creating a hunt, set hostName = PlayerIdentity.name. Update MAP.md.

✅ Check: AirDrop a hunt from one phone to another (or share to Files in the Simulator and open it) → "Join?" sheet → hunt appears and is playable.

### B3 · 2:30–3:30 · Wire Host / Join / synced Start / leaderboard into the flow
Uses A's `HostLobbyView` / `JoinView` and C's `RaceSession` / `LeaderboardView`. If those aren't on `main` yet, build against the signatures in SPEC.md section 6 with placeholder views and swap them in when they land.

> /plan Wire the race flow: (1) On each playable hunt, add a "Host race" action that presents HostLobbyView(hunt:package:onStart:). onStart(date): RaceSession.shared.begin(huntShareID: hunt.shareID, total: count, isHost: true), dismiss the lobby, and start PlayView at `date` (show a 3-2-1 countdown until then). (2) Add a "Join" toolbar button (person.2.badge.plus) that presents JoinView(initialCode:onJoined:). onJoined(package): import it with importHunt(into:), keep showing the waiting state, and when NearbySession.shared.startAt is set, call RaceSession.shared.begin(huntShareID:total:isHost: false) and start PlayView at that date with the same countdown. (3) .onOpenURL: if RoomCode.code(from: url) returns a code, present JoinView(initialCode: code). (4) In HuntSession.clearCurrent, after advancing, call RaceSession.shared.reportProgress(cleared: currentIndex, total: checkpoints.count) when RaceSession.shared.isActive. (5) In PlayView, add a toolbar button (list.number) that shows LeaderboardView in a sheet when a race is active, plus a compact "You're 2nd" pill under the progress bar. Update MAP.md.

### B4 · 3:30–4:00 · Cleared + Finished screens (with leaderboard)
> /plan Create Quarry/Hunt/CheckpointClearedView.swift (big green checkmark with spring, "Checkpoint 2 cleared!", the checkpoint thumbnail, split time mm:ss, "You're 2nd" if racing, Next clue / Finish button, .sensoryFeedback(.success)) and Quarry/Hunt/HuntFinishedView.swift ("Hunt complete!", total time, split times, and LeaderboardView if a race is active, else a thumbnail grid; Done button). Track split times in HuntSession (`splitTimes: [TimeInterval]`). Wire both into PlayView. Update MAP.md.

---

## If we're behind (cut in this order)
1. Location (stretch already)
2. C4 rank in the Live Activity
3. B4 Finished screen (keep the simple one)
4. QR scanning (keep **typing the 4-letter code**, plus the iPhone Camera app opening `quarry://join` links)
5. The live leaderboard (keep joining + synced start)
6. Nearby joining entirely (keep **AirDrop sharing** from B2)

**Never cut:** camera ring + auto-capture, Live Activity, guard rails, AirDrop sharing, icon, Keynote.

## Demo script (1:30, 3 phones)
1. Problem (spoken): "Our club's orientation hunt: 40 freshmen sent photos to a group chat, and an officer spent an hour checking them."
2. **Host** opens the hunt → **Host race** → a big QR on screen.
3. Two teammates **scan the QR** → their phones show "Joined Orientation Hunt · 3 checkpoints" → the host sees "Maya joined ✓, Jordan joined ✓".
4. Host taps **Start for everyone** → 3-2-1 on all three phones → **three Dynamic Islands light up** at once.
5. A teammate points the camera at a wrong object (ring stays low), then the right one: ring fills, buzz, **cleared** → the **host's leaderboard reorders live**.
6. Lock a phone: the Lock Screen shows the clue and progress (and the Watch, if available).
7. "No internet, no accounts: phone-to-phone, verified on-device."

## Demo-day checklist (6:15)
- [ ] All 3 demo phones have the latest build installed from Xcode
- [ ] Each phone has a player name set; Local Network permission already granted (do one practice join)
- [ ] Demo hunt references are objects physically on stage
- [ ] Wrong object → ring stays low; right object → clears in under 2 s
- [ ] Join works in the pitch room (practice once there); AirDrop fallback ready
- [ ] Island lights up on Start; leaderboard updates on clear
- [ ] Icon + final name; phones charged, Do Not Disturb on, Auto-Lock = Never
- [ ] Keynote has screenshots as a backup; Devpost submitted by 6:15
