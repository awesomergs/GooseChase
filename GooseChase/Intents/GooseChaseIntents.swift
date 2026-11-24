//
//  GooseChaseIntents.swift  ·  Siri, Spotlight, Shortcuts and Action Button support.
//    • "What's my clue in GooseChase"  → Siri reads the current clue + progress (hands-free)
//    • "Snap it in GooseChase"         → opens the camera for the current checkpoint
//                                        (great on the Action Button)
//    • "Join a game in GooseChase"     → asks for the room code, opens Join and connects
//  Snap + Join reuse the existing deep links (quarry://camera, quarry://join?code=XXXX).
//

import AppIntents
import Foundation

// The hunt being played right now (set by HuntSession.start, cleared on quit / finish).
extension HuntSession {
    static weak var active: HuntSession?
}

/// Spoken by Siri when an intent can't run.
nonisolated enum GooseIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noHunt, badCode

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noHunt: "Start a hunt in GooseChase first, then you can snap checkpoints."
        case .badCode: "Room codes are 4 letters. Check the host's screen and try again."
        }
    }
}

// MARK: - What's my clue?

nonisolated struct CurrentClueIntent: AppIntent {
    static let title: LocalizedStringResource = "Current Clue"
    static let description = IntentDescription("Hear the clue for the checkpoint you're hunting.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let session = HuntSession.active, !session.isFinished, let clue = session.current?.clue else {
            return .result(dialog: "You're not on a hunt right now. Start one in GooseChase.")
        }
        let minutes = Int(Date.now.timeIntervalSince(session.startDate) / 60)
        let elapsed = minutes == 0 ? "under a minute" : "\(minutes) minute\(minutes == 1 ? "" : "s")"
        return .result(dialog: "Checkpoint \(session.progressText), \(elapsed) in. Your clue: \(clue)")
    }
}

// MARK: - Snap it

nonisolated struct SnapCheckpointIntent: AppIntent {
    static let title: LocalizedStringResource = "Snap It"
    static let description = IntentDescription("Open the camera for your current checkpoint.")

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let session = HuntSession.active, !session.isFinished, session.current != nil else {
            throw GooseIntentError.noHunt
        }
        return .result(opensIntent: OpenURLIntent(URL(string: "quarry://camera")!))
    }
}

// MARK: - Join a game

nonisolated struct JoinGameIntent: AppIntent {
    static let title: LocalizedStringResource = "Join a Game"
    static let description = IntentDescription("Join a nearby GooseChase hunt with its room code.")

    @Parameter(title: "Room code", requestValueDialog: "What's the room code?")
    var code: String

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let clean = String(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
        guard clean.count == 4 else { throw GooseIntentError.badCode }
        return .result(opensIntent: OpenURLIntent(URL(string: "quarry://join?code=\(clean)")!))
    }
}

// MARK: - Phrases

nonisolated struct GooseChaseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentClueIntent(),
            phrases: [
                "What's my clue in \(.applicationName)",
                "What's my \(.applicationName) clue",
                "Read my \(.applicationName) clue",
                "Ask \(.applicationName) for my clue",
                "\(.applicationName) clue",
            ],
            shortTitle: "Current Clue",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: SnapCheckpointIntent(),
            phrases: [
                "Snap it in \(.applicationName)",
                "Open the \(.applicationName) camera",
            ],
            shortTitle: "Snap It",
            systemImageName: "camera.fill"
        )
        AppShortcut(
            intent: JoinGameIntent(),
            phrases: [
                "Join a game in \(.applicationName)",
                "Join \(.applicationName)",
            ],
            shortTitle: "Join a Game",
            systemImageName: "qrcode.viewfinder"
        )
    }
}
