# Quarry: Team Plan for Today

**Now → 5:30 build · 5:30 feature freeze · 6:30 submit · 7:00 pitch**

Read `SPEC.md` (what we're building) and `MAP.md` (where the code is) first. This file is **who does what, when, and what to type into the Xcode agent.**

| Person | Name | Owns | One-line goal |
|---|---|---|---|
| **A** | _______ | `Quarry/Vision/` | Point the camera at the right thing → the ring fills → auto-capture → cleared |
| **B** | _______ | `Quarry/Hunt/`, `ContentView.swift` | Create a hunt with photos, play it start to finish, and make it look like an Apple app |
| **C** | Rohan | `Quarry/LiveActivity/`, `QuarryWidgets/`, project settings, icon, Keynote | Dynamic Island + Lock Screen + Watch, the icon, the pitch; runs the merges |

---

## The whole day at a glance

| Time | A (Vision) | B (Hunt flow) | C (Rohan) |
|---|---|---|---|
| 11:00–11:30 | Setup (everyone, below) | Setup | Push skeleton, help clone, set up demo phone |
| 11:30–1:00 | Camera preview + live match score | Create-hunt + checkpoint editor with photos | Live Activity working on a device or simulator |
| **1:00** | **MERGE 1**: push your branch | **MERGE 1**: push your branch | **Merges, builds, tests on phone** |
| 1:00–2:30 | Confidence ring, auto-capture, haptics | Play-flow screens: clue, cleared, finished | Island polish, Watch, alert-on-clear |
| 2:30–4:00 | Tune thresholds on real objects | Liquid Glass/design polish, Test match | App icon (Icon Composer), stretch App Intent |
| **4:00** | **MERGE 2** | **MERGE 2** | **Merges, full run-through on phone** |
| 4:00–5:30 | Bug fixes, speed, stretch: Object checkpoints | Bug fixes, edge cases, empty states | Keynote, screenshots, demo checklist |
| **5:30** | **FEATURE FREEZE**: bug fixes only | | |
| 5:30–6:15 | Set up demo hunt in the pitch room | Rehearse demo flow | Final merge, Keynote, **submit on Devpost by 6:15** |
| 6:30–7:00 | Rehearse the pitch twice with a timer (everyone) | | |

**Phones:** the Simulator has **no camera**. A needs a real iPhone all day. B needs one for photo capture, but can use the Simulator plus photo-library images for most screens. C can test the Live Activity on an **iPhone 17 Pro Simulator**, which has a Dynamic Island, until Rohan's phone finishes updating. Pick **one demo phone** with a Dynamic Island (iPhone 14 Pro or newer) for the pitch.

---

## 11:00–11:30 · Setup (everyone)

1. **Get the code.** GitHub Desktop → File → Clone Repository → `Quarry` → open `Quarry.xcodeproj`.
2. **Signing.** Click the blue Quarry project at the top of the left sidebar → under TARGETS select `Quarry` → Signing & Capabilities → Team = your Personal Team. Do the same for `QuarryWidgetsExtension`. **Don't commit this change** (uncheck `project.pbxproj` in GitHub Desktop when committing).
   - If you see "bundle identifier is not available," change `rgs.Quarry` to `yourname.Quarry` locally. Also don't commit that.
3. **Build.** Pick your iPhone (or a simulator) at the top of Xcode → ⌘R. You should see "Quarry" with a "Birthday Hunt" row. Tap it, then "Open camera," then "Pretend cleared." The whole flow works as a stub.
4. **Your branch.** GitHub Desktop → Branch → New Branch: `vision` (A), `hunt` (B), `live-activity` (C).
5. **Agent.** Xcode → Settings → Intelligence → pick Claude Agent or Codex (USC students get Codex free) → sign in.
6. **Agent skills are already in the repo** (`.agents/skills/` and `.claude/skills/`): **SwiftUI Pro** (everyone), **SwiftData Pro** (B), **Swift Concurrency Pro** (A: Vision off the main thread). Nothing to install. Invoke with "Use the SwiftUI Pro skill" (or `/swiftui-pro` in Claude, `$swiftui-pro` in Codex). Good habit: after a big change, ask "Use the SwiftUI Pro skill to review what you just wrote."
7. **First message to your agent** (paste once at the start of each new conversation):
   > Read AGENTS.md, SPEC.md and MAP.md in the repo root. I am Person [A/B/C]. Summarize in 3 bullets what I own, which files I'm allowed to edit, and the contracts I must keep. Don't change any code yet.

**Working loop for every task below:** type `/plan` + the prompt → read the plan and fix anything that touches files outside your folder → let it build → **run it on the phone yourself** → commit in GitHub Desktop with a short message. Commit every 20–30 minutes.

---

## Person A · Camera + Vision

**You own:** `Quarry/Vision/` (`VerifyCameraView.swift`, `VisionMatcher.swift`, plus any new files you add there).
**Keep stable:** `VerifyCameraView(checkpoint: Checkpoint, onCleared: () -> Void)`, and the three `VisionMatcher` functions.
**You need:** a real iPhone the whole time.

### A1 · 11:30–12:15 · Live camera preview
Goal: `VerifyCameraView` shows the back camera full screen.

> /plan In Quarry/Vision, replace the body of VerifyCameraView with a full-screen live back-camera preview using AVFoundation. Create a new file Quarry/Vision/CameraController.swift with an @Observable class that owns an AVCaptureSession (photo preset), asks for camera permission, starts the session on a background queue, and exposes the latest video frame as a CGImage at most 5 times per second via AVCaptureVideoDataOutput. Show the preview with a UIViewRepresentable wrapping AVCaptureVideoPreviewLayer. Keep the existing initializer VerifyCameraView(checkpoint:onCleared:) and keep a small "Pretend cleared" button in the corner for now. Don't edit files outside Quarry/Vision. Update MAP.md for the new file.

✅ Check: open the camera from the play screen → live video, no freezing, the permission prompt appears the first time.

### A2 · 12:15–1:00 · "Set reference" mode + live match score
The demo hunt has no reference photos yet, so build a way to add them from the camera itself. This doubles as the host's **Test match** tool.

> /plan In VerifyCameraView: if checkpoint.referencePrints is empty, show a "Set reference" button that grabs the current frame, calls VisionMatcher.makeReferencePrint, appends it to checkpoint.referencePrints, and saves a ≤300px JPEG to checkpoint.thumbnail if it's nil. Allow adding up to 3 references. When references exist, run VisionMatcher.bestDistance on each sampled frame OFF the main thread (Task.detached), convert with VisionMatcher.score(forDistance:), and show a debug label with both the raw distance and the score as a percentage. Throttle so at most one Vision request is in flight at a time.

✅ Check: set a reference on a mug → point at the same mug → note the distance. Point at a different object → note the distance. **Write both numbers down**; you'll tune with them.

**→ 1:00 MERGE 1.** Commit, push the `vision` branch, and tell Rohan "vision pushed." The "Pretend cleared" button stays so the flow still works if something's off.

### A3 · 1:00–2:30 · Confidence ring + auto-capture (the demo moment)
> /plan In VerifyCameraView, replace the debug UI with the final design: a large circular shutter button at the bottom with a confidence ring around it (trim-based Circle stroke, lineWidth ~6, animated with .spring when the score changes). Ring color: white below 50%, yellow 50–84%, green at ≥ threshold. Above it, a big "Match 72%" label and a one-line tip ("Get the whole thing in frame"). At the top, a capsule chip with the checkpoint clue and an X close button (use .glassEffect only on these floating controls). Auto-capture: when the score stays ≥ threshold for 0.5 seconds, freeze the frame, play .sensoryFeedback(.success), show a green checkmark for 0.6 s, then call onCleared() exactly once. Manual shutter: if tapped below threshold, show "Not quite. Try another angle," with .sensoryFeedback(.error). Remove the Pretend cleared button only in DEBUG builds behind a long-press on the close button. Add .sensoryFeedback(.increase) each time the score crosses another 25%.

✅ Check: aim at the right object → ring fills smoothly → buzz → clears within ~2 s. Aim at a wrong object → the ring stays low. The close button works.

### A4 · 2:30–3:30 · Tune thresholds on real objects
Test **at least 5 objects in the actual room** (bottle, mug, backpack, laptop, plant), under room lighting.

> /plan Update VisionMatcher.score(forDistance:) defaults using these measurements: same-object distances were [__, __, __], different-object distances were [__, __, __]. Set `strong` just above the typical same-object distance and `weak` just below the typical different-object distance. Add a comment with the measurements and the date. Also make the auto-capture threshold a single constant at the top of VerifyCameraView.

Tips: 2–3 reference photos from different angles help a lot. If two similar mugs both pass, tighten `strong`.

### A5 · 3:30–4:00 · Speed + reliability
> /plan Profile VerifyCameraView on device. Make sure Vision runs off the main thread, the camera session stops when the view disappears, and nothing leaks when opening and closing the camera 10 times. Downscale frames to ~512 px on the longest side before computing the feature print if that speeds it up.

**→ 4:00 MERGE 2.** Push and tell Rohan.

### A6 · 4:00–5:30 · Stretch: Object checkpoints (only if A1–A5 are solid)
> /plan Add support for checkpoint.kind == .object in VerifyCameraView: run VNClassifyImageRequest on sampled frames and use the confidence of checkpoint.targetLabel (case-insensitive match against observation identifiers) as the score. Ring and auto-capture behave exactly the same. Add VisionMatcher.classificationScore(for:label:) for this and update MAP.md.

### A7 · 5:30–6:30 · Demo prep
In the pitch room, set references on 2–3 objects that will definitely be on stage. Run the full demo 3 times. Note any object that fails and swap it.

---

## Person B · Hunt flow + data

**You own:** `Quarry/Hunt/`, `ContentView.swift` (you can move views out of it into `Quarry/Hunt/`).
**Keep stable:** the models in `Shared/Models.swift`, and `HuntSession` stays the only thing that calls `LiveActivityManager`.
**You need:** a phone for photo capture; the Simulator is fine for layout.

### B1 · 11:30–12:15 · Camera photo picker + checkpoint editor
> /plan Create Quarry/Hunt/CameraPicker.swift: a UIViewControllerRepresentable wrapping UIImagePickerController with sourceType .camera (fall back to .photoLibrary when the camera is unavailable, e.g. in the Simulator) that returns a UIImage. Then create Quarry/Hunt/CheckpointEditorView.swift: a Form for one Checkpoint with a clue TextField (axis: .vertical), a "Reference photos" section showing up to 3 thumbnails in an HStack plus an "Add photo" button that opens CameraPicker. When a photo comes back, call VisionMatcher.makeReferencePrint(from:) on a background task, append to checkpoint.referencePrints, and set checkpoint.thumbnail to a ≤300px JPEG if nil. Show a ProgressView while processing and an inline error if it throws. Update MAP.md.

✅ Check: add 2 photos to a checkpoint → thumbnails appear → relaunch the app → still there (SwiftData saved).

### B2 · 12:15–1:00 · Create + edit hunts
> /plan Create Quarry/Hunt/HuntEditorView.swift: edit a Hunt's title and list its orderedCheckpoints (clue text + thumbnail). Support "Add checkpoint" (creates a Checkpoint with the next order and pushes CheckpointEditorView), swipe to delete, and drag to reorder (rewrite each checkpoint's order). In ContentView, add a "+" toolbar button that creates a new Hunt and pushes HuntEditorView, an Edit swipe action on each hunt row, and swipe-to-delete. Show each hunt's first checkpoint thumbnail in its row. Use NavigationStack with navigationDestination, not NavigationView.

✅ Check: create "Test Hunt" with 3 checkpoints from scratch, each with photos.

**→ 1:00 MERGE 1.** Commit, push `hunt`, and tell Rohan "hunt pushed."

### B3 · 1:00–2:30 · Play flow screens (match the mock-ups)
> /plan Move PlayView out of ContentView into Quarry/Hunt/PlayView.swift and redesign it: a top bar with an End button (xmark) and the elapsed time (Text(session.startDate, style: .timer), monospaced digits); a segmented progress bar (one capsule per checkpoint: cleared = indigo, current = indigo 45% opacity, upcoming = secondary 25%); "Checkpoint 2 of 5" in .headline secondary; the clue in .title2 semibold in a rounded card; a large .borderedProminent "Open camera" button at the bottom. After VerifyCameraView calls onCleared, show a CheckpointClearedView (big green checkmark, "Checkpoint 2 cleared!", split time for that checkpoint, a "Next clue" button) with .sensoryFeedback(.success). When the last checkpoint clears, show HuntFinishedView: "Hunt complete!", total time, and a grid of the checkpoint thumbnails, with a Done button. Keep the .onOpenURL handler for quarry://camera. Track per-checkpoint split times inside HuntSession. Update MAP.md.

✅ Check: play the demo hunt start to finish; split and total times look right; End mid-hunt works.

### B4 · 2:30–3:15 · Test match + demo data
> /plan In CheckpointEditorView add a "Test match" button (enabled when the checkpoint has at least one reference photo) that presents VerifyCameraView(checkpoint:onCleared:) full screen; when it clears, dismiss and show a "Works!" checkmark next to the button.

### B5 · 3:15–4:00 · Make it look like an Apple app
> /plan Polish all hunt screens for iOS 26 Liquid Glass and the Human Interface Guidelines: use system List/Form styles, large navigation titles, SF Symbols, Dynamic Type text styles only (no fixed font sizes), indigo as the accent color. Liquid Glass only on floating controls and toolbars, never on content cards. Add ContentUnavailableView for "No hunts yet" and "No checkpoints yet." Add .sensoryFeedback on add/delete. Make sure every icon-only button has an accessibilityLabel. Don't change Shared/ or Vision/.

**→ 4:00 MERGE 2.** Push and tell Rohan.

### B6 · 4:00–5:30 · Bugs + edge cases
Run through these on the phone and fix what breaks:
- A hunt with 0 checkpoints (Start should be disabled).
- A checkpoint with no reference photos during play (VerifyCameraView's "Set reference" mode should appear).
- Kill the app mid-hunt and relaunch (the stale Live Activity should be cleaned up).
- Very long clue text; large Dynamic Type size (Settings → Accessibility → Larger Text).

### B7 · 5:30–6:30 · Pitch prep
Write and rehearse the **Problem** slide story (30 seconds): the birthday party, kids shouting "I found it!", the parent can't check everyone's finds. Help A set up the demo hunt.

---

## Person C (Rohan) · Live Activity, platform, merges, pitch

**You own:** `Quarry/LiveActivity/`, `QuarryWidgets/`, `project.pbxproj`, `QuarryApp.swift`, the icon and the Keynote.

### C1 · 11:00–11:30 · Unblock the team
- Commit and push the skeleton (with `SPEC.md`, `MAP.md`, `PLAN.md`) to `main` **before anyone clones**.
- Add both teammates as collaborators on GitHub (repo → Settings → Collaborators).
- Make sure each teammate builds once. Signing errors are usually the bundle ID; change it locally.
- Pick the demo phone (Dynamic Island, charged).

### C2 · 11:30–12:30 · Live Activity working
Until your phone updates, use the **iPhone 17 Pro Simulator** (it supports Live Activities and the Dynamic Island).
1. Switch the scheme to `QuarryWidgetsExtension` → open `QuarryWidgets/QuarryWidgetsLiveActivity.swift` → check all 4 previews render.
2. Switch the scheme back to `Quarry` → run → tap Birthday Hunt → swipe home → the island shows `1/3` + timer → lock (⌘L in the Simulator) → the Lock Screen shows the activity.
3. "Pretend cleared" → go Home → the island shows 2/3. Long-press it → "Open camera" opens the app's camera. (iOS hides the activity while the app is open, so there is no pop-open on clear.)

If anything fails:
> /plan The Live Activity does not appear when HuntSession.start() runs. Read MAP.md. Check LiveActivityManager, HuntActivityAttributes target membership (it must be in both Quarry and QuarryWidgetsExtension), the NSSupportsLiveActivities build setting, and QuarryWidgetsBundle. Explain the cause before changing anything.

### C3 · 12:30–1:00 · Polish the island layouts
> /plan Polish QuarryWidgets/QuarryWidgetsLiveActivity.swift to match iOS system Live Activities: compact leading = a small progress ring (Circle trim of checkpointIndex/totalCheckpoints in indigo) with the "2/5" text; compact trailing = elapsed timer in monospaced digits with a fixed width so it doesn't push the island wider; minimal = the progress ring only; expanded = leading "Checkpoint 2 of 5", trailing timer, bottom = the clue (2 lines max) and an indigo capsule "Open camera" Link to quarry://camera. When justCleared is true, show a green checkmark and "Cleared!" instead of the clue. Keep the Lock Screen and the .small Watch layouts consistent. Update the previews. Don't change HuntActivityAttributes.

### C4 · 1:00–1:30 · MERGE 1 (you run it)
In GitHub Desktop:
1. Commit your work on `live-activity`. Switch to `main`.
2. **Branch → Merge into Current Branch → `hunt`** (B first; A's code depends on nothing of B's). Build (⌘B).
3. **Branch → Merge into Current Branch → `vision`.** Build. Then merge `live-activity`.
4. If there's a conflict in `MAP.md`, keep both sides' lines. If it's in a Swift file, open it in Xcode, keep both changes, build.
5. Run on the phone: play the hunt with A's real camera. **Push `main`.**
6. Tell the team: "main updated: pull it into your branch" (GitHub Desktop: on your branch → Branch → Merge into Current Branch → `main`).

### C5 · 1:30–2:15 · Watch + alert + stale cleanup
- If anyone has an Apple Watch on watchOS 11+: pair it with the demo phone, start a hunt, and raise your wrist. The Smart Stack should show the `.small` layout.
- Confirm that relaunching the app ends leftover activities (`endAllStale` in ContentView).
- Check that "Open camera" in the expanded island opens the camera on the demo phone, and that the activity disappears ~3 minutes after finishing.

### C6 · 2:15–2:45 · App icon (Icon Composer, not AI)
1. Xcode → Open Developer Tool → Icon Composer.
2. In the SF Symbols app, export `viewfinder` (or `scope`) as SVG. Drop it in and set an indigo gradient background. Preview the Liquid Glass and dark appearances.
3. Save as `AppIcon.icon` → drag into Xcode's `Quarry` folder → Target → General → App Icon = `AppIcon` → run → check the Home Screen.

### C7 · 2:45–3:45 · Stretch: Siri / Shortcuts App Intent (good for the "Why Apple" slide)
> /plan Add an App Intent in Quarry/LiveActivity/StartHuntIntent.swift: "Start a Quarry hunt" that opens the app and starts the most recently created hunt, plus an AppShortcutsProvider with the phrase "Start a hunt in \(.applicationName)". Don't change Shared/ or Hunt/; if you need a hook into ContentView, tell me what minimal change Person B should make. Update MAP.md.

Skip it if anything earlier is shaky.

### C8 · 4:00–4:30 · MERGE 2 (same steps as C4)
Then do a **full run-through on the demo phone**: create a hunt → set references → play → island → lock screen → finish.

### C9 · 4:30–5:30 · Keynote (4 slides, 3 minutes)
1. **Problem** (0:30, B speaks): one photo or illustration + one line: "At my niece's party, nobody could tell who really found what."
2. **Live demo** (1:30, A drives the phone, C narrates): use a screen-mirroring cable or QuickTime → New Movie Recording → choose the iPhone, to project it.
3. **Why it's an Apple app** (0:45, C): on-device Vision (private, offline, instant) · Live Activity + Dynamic Island · Apple Watch Smart Stack · haptics · Liquid Glass. Show 2 screenshots: the island expanded and the Lock Screen.
4. **What's next** (0:15): "Find anything red": Object checkpoints and AI-written riddles with Foundation Models.

Take screenshots on the demo phone (side button + volume up) for slide 3 and as a backup if the live demo fails.

### C10 · 5:30–6:30 · Freeze, submit
- 5:30: announce the freeze. Only crash fixes after this.
- 5:45: final merge of all branches to `main` → build → run on the demo phone → push.
- **6:15: submit on Devpost** with the GitHub repo link + the Keynote file. Don't wait until 6:29.
- Demo phone: charged, Do Not Disturb on, Auto-Lock = Never, demo hunt pre-loaded with references for objects in the room, old activities ended.

---

## Communication rules

- One group chat. Post "pushed `<branch>`" after every push, and "changing Shared/…" **before** touching `Shared/`.
- Stuck for 15 minutes? Say so. Someone else might know, or it's time to cut the feature.
- Anything that needs a capability, Info.plist key or target change → ask Rohan.
- Don't merge into `main` yourself; Rohan merges, so `main` always builds.

## If we're behind (cut in this order)
1. Object checkpoints (A6)
2. The App Intent (C7)
3. Drag to reorder and edit-hunt (B2 extras)
4. The create flow entirely: hard-code the demo hunt and set references in the room with A2's "Set reference" mode

**Never cut:** the confidence ring + auto-capture, the Live Activity + Dynamic Island, the icon, the Keynote.

## Demo-day checklist (6:15)
- [ ] App icon shows on the Home Screen
- [ ] Demo hunt has references for objects that are physically in the room
- [ ] Wrong object → ring stays low; right object → clears in under 2 s
- [ ] The island appears on Start (go Home), updates after each clear, and "Open camera" jumps into the camera
- [ ] The Lock Screen shows the clue + progress
- [ ] (If a watch) the Smart Stack shows the hunt
- [ ] Phone: charged, Do Not Disturb, Auto-Lock = Never
- [ ] Backup: screenshots in the Keynote + the app built on the Simulator on a laptop
- [ ] Devpost submitted with the repo + Keynote
