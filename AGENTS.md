# Agent instructions: GooseChase

Solo portfolio project by Rohan George. It started at the iOSC Fall 2026 Hackathon (team: Rohan, Cody, teammate B).
GooseChase is an iOS 26 SwiftUI scavenger-hunt app: on-device Vision checks finds; nearby multiplayer uses
MultipeerConnectivity; there's a Live Activity on the Dynamic Island, Lock Screen and Apple Watch; App Intents add Siri support.

## Read first
1. `MAP.md`: every file, what it does, how the flows connect. Use it instead of searching blindly.
2. `DESIGN.md`: the design system and the Liquid Glass rule (glass is for controls only, never for content cards or backgrounds).
3. Local planning notes (gitignored, may exist): `NIGHTLY_SUMMARY.md`, `docs/phase0/DEAD_CODE.md`,
   `docs/phase0/THEME_MERGE_PLAN.md`, `docs/phase0/ISSUES.md`. Current work is **Phase 0** (clean-up), in the order listed there.

## Project facts
- Xcode 26, iOS 26, Swift 5 language mode with **MainActor default isolation** and approachable concurrency.
  Types used off the main actor (Vision helpers, Canvas drawing, App Intents, Shape) are marked `nonisolated`.
- Folders are Xcode *synchronized groups*: any file inside `GooseChase/` joins the app target and any file inside `GooseChaseWidgets/` joins the widget
  target automatically. `GooseChase/Shared/HuntActivityAttributes.swift` is shared with the widget via a membership exception.
- Free Apple **Personal Team only**: no push, CloudKit, App Groups, TestFlight or App Clips. Don't add capabilities that need a paid account.
- No third-party packages, no backend.
- Keep these working even after the rename: the `quarry://` URL scheme (`quarry://join?code=XXXX`, `quarry://camera`), UTType `com.quarryapp.hunt`,
  Bonjour service `_quarry-hunt`.

## Build and test
- Build: `xcodebuild -project GooseChase.xcodeproj -scheme GooseChase -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Tests: `xcodebuild test -project GooseChase.xcodeproj -scheme GooseChase -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`
  (if that simulator name doesn't exist, run `xcrun simctl list devices available` and pick one).
- **Build after every change** and fix errors before moving on. Camera, Multipeer, Live Activity and Watch behavior can only be checked on
  Rohan's real devices; when a change needs that, stop and tell him exactly what to check.

## Rules
- **Git:** commit after each finished, building step, with a short plain message ("Theme: replace skyCard glass with solid card").
  **No AI attribution of any kind** in commits or PRs: no `Co-Authored-By`, no "Generated with" lines.
  **Never push, pull, force-push, rebase shared branches or open PRs** unless Rohan asks in this session.
  Work on the current feature branch; don't commit to `main`.
- **Never edit `project.pbxproj` by hand** for target/scheme/rename work. Ask Rohan to do it in Xcode's UI and give him the steps.
- **Deleting files:** only the ones listed in `docs/phase0/DEAD_CODE.md` (or ones Rohan approves), and only after removing every reference.
- If Xcode has a file open, it can overwrite your edits: if a file reverts unexpectedly, tell Rohan to close it in Xcode.
- If you add, rename or delete a file, or change a public type or function, update `MAP.md` in the same commit.
- Explain each change in 2–3 plain sentences; flag anything Rohan must verify on his phone.
