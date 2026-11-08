//
//  RaceMessages.swift  ·  SHARED CONTRACT (C). Change only after telling the team.
//  Everything sent over the nearby (MultipeerConnectivity) connection.
//  A's NearbySession sends/receives these; C's RaceSession interprets them.
//

import Foundation

/// One player's standing in the race.
nonisolated struct PlayerProgress: Codable, Sendable, Hashable, Identifiable {
    var id: String            // stable per phone (UUID string)
    var name: String          // display name, e.g. "Maya"
    var cleared: Int          // checkpoints cleared so far
    var total: Int
    var finishedAt: Date?     // set when cleared == total
    var updatedAt: Date
}

nonisolated enum NearbyMessage: Codable, Sendable {
    /// Player → host, right after connecting.
    case hello(player: PlayerProgress)
    /// Host → player: the hunt itself.
    case hunt(HuntPackage)
    /// Host → everyone: synced start time (a couple of seconds in the future, so all phones start together).
    case start(at: Date)
    /// Player → host: progress after each clear.
    case progress(PlayerProgress)
    /// Host → everyone: the full leaderboard, sent whenever anything changes.
    case leaderboard([PlayerProgress])

    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> NearbyMessage { try JSONDecoder().decode(NearbyMessage.self, from: data) }
}

/// Short room codes: 4 characters, no look-alikes (no 0/O, 1/I).
nonisolated enum RoomCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static func make() -> String { String((0..<4).map { _ in alphabet.randomElement()! }) }
    /// The QR code / link format: quarry://join?code=KQ7X (scanning with the iPhone Camera app opens Quarry).
    static func joinURL(_ code: String) -> URL { URL(string: "quarry://join?code=\(code)")! }
    static func code(from url: URL) -> String? {
        guard url.scheme == "quarry", url.host == "join" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value?.uppercased()
    }
}

/// This phone's identity in races. Stable across launches (UserDefaults).
nonisolated enum PlayerIdentity {
    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: "playerID") { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "playerID")
        return new
    }
    /// Editable display name; defaults to "Player". B can add a field for it on the Join screen.
    static var name: String {
        get { UserDefaults.standard.string(forKey: "playerName") ?? "Player" }
        set { UserDefaults.standard.set(newValue, forKey: "playerName") }
    }
}
