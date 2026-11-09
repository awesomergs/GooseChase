# GooseChase: Siri / App Intents handoff

## What the app is
GooseChase is a scavenger-hunt app built with SwiftUI on iOS 26 and Xcode 26. Someone hosts a hunt and everyone else joins nearby by QR code or a 4-letter room code. Each clue is solved by taking a photo, which on-device Vision checks.

The project and code are still called **Quarry**; only the displayed name is GooseChase. There's no server and we use a free Personal Team. App Intents need no special capability, so that's fine.

## Setup
- Pull the latest from Rohan (branch `near`, or `main` if it's merged), then work on a new branch called `siri`.
- Put all your files in a new folder, **`Quarry/Intents/`**. The folders sync automatically, so new files join the app target on their own and you won't need to touch `project.pbxproj`.
- The project is in Swift 5 mode with **MainActor as the default isolation**. If Xcode complains about actor isolation on an intent, mark the struct `nonisolated` and put `@MainActor` on `perform()`.
- The only existing file you'll change is `Hunt/HuntSession.swift` (3 lines, in step 2). **Send that change to Rohan instead of committing it yourself**, since he may have the file open.

## 1. Join a game by voice
This needs no changes to existing code. The app already handles `quarry://join?code=XXXX`, which switches to the Join tab and connects. The intent just opens that link.

```swift
import AppIntents

struct JoinGameIntent: AppIntent {
    static let title: LocalizedStringResource = "Join a Game"
    static let description = IntentDescription("Join a nearby GooseChase hunt with a room code.")

    @Parameter(title: "Room code") var code: String

    func perform() async throws -> some IntentResult & OpensIntent {
        let clean = String(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
        return .result(opensIntent: OpenURLIntent(URL(string: "quarry://join?code=\(clean)")!))
    }
}
```

## 2. "What's my clue?" while playing
Siri reads the current clue aloud, which is handy hands-free in the middle of a hunt.

First add a hook in `HuntSession.swift`:

```swift
static weak var active: HuntSession?   // add next to the other properties

// in start():
HuntSession.active = self

// in quit(), and wherever the hunt finishes:
HuntSession.active = nil
```

Then the intent:

```swift
struct CurrentClueIntent: AppIntent {
    static let title: LocalizedStringResource = "Current Clue"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let session = HuntSession.active, let clue = session.current?.clue else {
            return .result(dialog: "You're not in a hunt right now.")
        }
        return .result(dialog: "Checkpoint \(session.progressText): \(clue)")
    }
}
```

## 3. Register the phrases
This is what makes them show up in Siri, Spotlight, the Shortcuts app and the Action Button. Every phrase has to include `\(.applicationName)`.

```swift
struct GooseChaseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CurrentClueIntent(),
                    phrases: ["What's my clue in \(.applicationName)",
                              "Read my \(.applicationName) clue"],
                    shortTitle: "Current Clue", systemImageName: "text.bubble")
        AppShortcut(intent: JoinGameIntent(),
                    phrases: ["Join a game in \(.applicationName)",
                              "Join \(.applicationName)"],
                    shortTitle: "Join a Game", systemImageName: "qrcode.viewfinder")
    }
}
```

## Testing
- Build to a phone and open the app once; that's how the phrases get registered.
- Test in the **Shortcuts app** first (search "GooseChase"), then try Siri. Phrases can take a minute to show up.
- The hackathon room is loud, so for the demo either trigger it from a Shortcuts tile or the Action Button, or say the phrase close to the phone.

## Timing
Submission is at 6:30 and we're aiming to submit by 6:15. If it isn't working by **6:00**, stop, and leave the branch unmerged. Step 1 alone is still a good demo.

## When you're done
Tell Rohan which steps work and which branch they're on, and send him the `HuntSession` change. For the pitch, the line is "Siri reads you the clue mid-hunt", which counts under Platform Integration.
