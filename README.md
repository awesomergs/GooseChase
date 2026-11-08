# Quarry

Scavenger hunts where the phone is the referee: on-device Vision checks that you found the right thing,
and the hunt runs live on the Lock Screen, Dynamic Island and Apple Watch.

## Who owns what (only edit your own folder)

| Person | Folder | Job |
|---|---|---|
| A | `Quarry/Vision/` | Camera, Vision matching, confidence ring, auto-capture, haptics |
| B | `Quarry/Hunt/`, `ContentView.swift` | SwiftData flow: hunt list, create checkpoint, play, cleared, finish |
| C | `Quarry/LiveActivity/`, `QuarryWidgets/` | Live Activity + Dynamic Island + Watch, app icon, Keynote |

`Quarry/Shared/` is the contract (models + Live Activity data). Change it only after telling the team.

## How the pieces connect
- B shows `VerifyCameraView(checkpoint:onCleared:)`. A replaces its body but keeps that initializer.
- A uses `VisionMatcher.makeReferencePrint(from:)` and `bestDistance(from:to:)`.
- B's `HuntSession` calls `LiveActivityManager` (C) on start / clear / finish.
- Tapping the Live Activity opens `quarry://camera`, handled in `PlayView`.

## Rules
- Work on your own branch; merge at 1:00, 4:00, 5:30.
- Only Rohan changes targets, capabilities or project settings (avoids `project.pbxproj` conflicts).
- Set Signing Team to your own Personal Team locally, but don't commit that change.
