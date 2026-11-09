# GooseChase 🪿

**Scavenger hunts where your iPhone is the referee.** Hide things, snap a few reference photos, write clues, and invite friends nearby. On-device Vision checks every find, so nobody has to run around confirming answers.

Built in about 8 hours at the iOSC Fall 2026 Hackathon with Swift and SwiftUI, for iOS 26. There's no server and no accounts; everything runs on device.

## How it plays
1. **Create:** make a hunt. For each checkpoint, write a clue and take 1–3 reference photos of the hidden object.
2. **Host:** pick a hunt. Friends nearby scan your QR code, or type the 4-letter room code, and appear in your lobby.
3. **Chase:** everyone starts together after a synced 3-2-1. Point the camera at what you think the clue means; when it matches, the checkpoint clears automatically.
4. **Finish:** see your total time, the time for each checkpoint, and the photos you found.

## Apple platform features
| Feature | How GooseChase uses it |
|---|---|
| **Vision** | Image feature prints compare the camera feed with the reference photos, on device. Each frame is also checked as a center crop and a crop around the main object, and the score is smoothed over a few frames. |
| **MultipeerConnectivity** | Nearby joining with no server. The host sends the whole hunt to each player and starts everyone at the same moment. |
| **VisionKit + Core Image** | QR codes to join. The iPhone Camera app can also open `quarry://join?code=XXXX` links. |
| **ActivityKit** | A Live Activity on the Lock Screen, in the Dynamic Island, and in the **Apple Watch Smart Stack**, with an animated goose that turns green when you clear a checkpoint. Tapping it opens the camera. |
| **App Intents** | "What's my clue in GooseChase" (Siri reads the clue), "Snap it" (opens the camera; works with the Action Button), and "Join a game". These also appear in Spotlight and Shortcuts. |
| **SwiftData** | Saves hunts, checkpoints, reference prints, best times and recent games. |
| **Liquid Glass + Icon Composer** | Glass controls and cards over a sky-and-grass look, plus a layered app icon with dark and tinted versions. |
| **Transferable / UTType** | Share a hunt as a `.quarryhunt` file over AirDrop. |

## Running it
- Xcode 26, iOS 26, a real iPhone (the camera, Live Activities and nearby play need a device).
- Open `Quarry.xcodeproj`, choose the **Quarry** scheme, set Signing to your own team, then build and run.
- For nearby play, install on two or more phones and allow **Local Network** when asked.
- The code and project are named **Quarry**, the hackathon codename. The app shows as **GooseChase**.

## Project map
- `Quarry/Hunt/`: create, play, cleared and finished screens, and the hunt session
- `Quarry/Nearby/`: Join and Host tabs, lobby, QR, MultipeerConnectivity session
- `Quarry/Vision/`: camera and Vision matching
- `Quarry/Design/`: theme, sky and grass scene, the goose mascot (`GooseView`)
- `Quarry/Intents/`: Siri, Shortcuts and Action Button intents
- `QuarryWidgets/`: Live Activity, Dynamic Island and Apple Watch layouts

See `MAP.md`, `SPEC.md` and `DESIGN.md` for details.

## What's next
- Smarter matching: combine feature prints with on-device object labels, and set the match threshold per checkpoint.
- More game modes: team races and timed rounds.
- Share hunts online with CloudKit (beyond nearby play and AirDrop).
