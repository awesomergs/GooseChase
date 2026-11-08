//
//  RaceSession.swift  ·  OWNER: Person C (Rohan)
//  Live standings for a hosted race. Transport-agnostic: NearbySession (A) delivers
//  incoming messages via `receive(_:)` and plugs itself in as `sendHandler`.
//
//  Flow:
//    host:   begin(isHost: true)  → reportProgress → broadcasts .leaderboard to everyone
//    player: begin(isHost: false) → reportProgress → sends .progress to host
//    host receives .hello/.progress → merges → broadcasts .leaderboard
//    player receives .leaderboard  → replaces standings
//

import Foundation
import Observation

@Observable
@MainActor
final class RaceSession {
    static let shared = RaceSession()

    private(set) var isActive = false
    private(set) var isHost = false
    private(set) var huntShareID: UUID?
    private(set) var startDate: Date?
    /// Sorted standings: finished players first (earliest finish wins), then most cleared,
    /// then whoever reached that count first.
    private(set) var players: [PlayerProgress] = []

    /// How this session sends messages. NearbySession (A) sets this when it starts:
    /// `RaceSession.shared.sendHandler = { [weak self] in self?.send($0) }`.
    /// Nil means solo play: everything still works locally, nothing is sent.
    var sendHandler: ((NearbyMessage) -> Void)?

    let myID: String = PlayerIdentity.id

    init() {}

    // MARK: - Derived

    var me: PlayerProgress? { players.first { $0.id == myID } }
    var myRank: Int? { rank(of: myID) }
    var racerCount: Int { players.count }

    func rank(of id: String) -> Int? {
        players.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    /// Time from race start to this player's finish, if finished.
    func finishTime(of player: PlayerProgress) -> TimeInterval? {
        guard let startDate, let finishedAt = player.finishedAt else { return nil }
        return max(0, finishedAt.timeIntervalSince(startDate))
    }

    // MARK: - Lifecycle

    /// Call when the race starts on this phone (host after "Start for everyone",
    /// player when the host's start message arrives). Keeps players who already
    /// said hello in the lobby. Call `end()` before hosting a new race.
    func begin(huntShareID: UUID, total: Int, isHost: Bool, startAt: Date = .now) {
        self.huntShareID = huntShareID
        self.isHost = isHost
        self.startDate = startAt
        self.isActive = true

        var mine = me ?? PlayerProgress(id: myID, name: PlayerIdentity.name, cleared: 0,
                                        total: total, finishedAt: nil, updatedAt: .now)
        mine.name = PlayerIdentity.name
        mine.cleared = 0
        mine.total = total
        mine.finishedAt = nil
        mine.updatedAt = .now
        upsert(mine)

        if isHost {
            broadcastLeaderboard()
        } else {
            sendHandler?(.progress(mine))
        }
    }

    /// B's HuntSession calls this after every clear (cleared = how many are done now).
    func reportProgress(cleared: Int, total: Int) {
        guard isActive else { return }
        var mine = me ?? PlayerProgress(id: myID, name: PlayerIdentity.name, cleared: 0,
                                        total: total, finishedAt: nil, updatedAt: .now)
        mine.cleared = min(cleared, total)
        mine.total = total
        mine.updatedAt = .now
        if mine.cleared >= total, mine.finishedAt == nil {
            mine.finishedAt = .now
        }
        upsert(mine)

        if isHost {
            broadcastLeaderboard()
        } else {
            sendHandler?(.progress(mine))
        }
    }

    /// NearbySession (A) forwards .hello / .progress / .leaderboard here.
    func receive(_ message: NearbyMessage) {
        switch message {
        case .hello(let player), .progress(let player):
            // Only the host collects individual updates (players can arrive before
            // the host calls begin, while still in the lobby).
            guard player.id != myID else { return }
            upsert(player)
            if isHost { broadcastLeaderboard() }

        case .leaderboard(let standings):
            guard !isHost else { return }
            // Keep our own latest entry if it's newer than what the host last saw.
            var merged = standings
            if let mine = me,
               let i = merged.firstIndex(where: { $0.id == myID }),
               merged[i].updatedAt < mine.updatedAt {
                merged[i] = mine
            }
            players = Self.sorted(merged)

        case .hunt, .start:
            break   // handled by NearbySession
        }
    }

    /// Race over or abandoned. Also call before hosting a new race.
    func end() {
        isActive = false
        isHost = false
        huntShareID = nil
        startDate = nil
        players = []
    }

    // MARK: - Private

    private func upsert(_ player: PlayerProgress) {
        if let i = players.firstIndex(where: { $0.id == player.id }) {
            players[i] = player
        } else {
            players.append(player)
        }
        players = Self.sorted(players)
    }

    private func broadcastLeaderboard() {
        sendHandler?(.leaderboard(players))
    }

    static func sorted(_ list: [PlayerProgress]) -> [PlayerProgress] {
        list.sorted { a, b in
            switch (a.finishedAt, b.finishedAt) {
            case let (fa?, fb?): return fa < fb
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none):
                if a.cleared != b.cleared { return a.cleared > b.cleared }
                return a.updatedAt < b.updatedAt
            }
        }
    }
}

// MARK: - Preview data

extension RaceSession {
    /// A session filled with fake racers, for #Previews.
    static func preview(meCleared: Int = 2) -> RaceSession {
        let race = RaceSession()
        let start = Date.now.addingTimeInterval(-15 * 60)
        race.huntShareID = UUID()
        race.startDate = start
        race.isActive = true
        race.isHost = true
        race.players = sorted([
            PlayerProgress(id: "maya", name: "Maya", cleared: 5, total: 5,
                           finishedAt: start.addingTimeInterval(11 * 60 + 42), updatedAt: .now),
            PlayerProgress(id: race.myID, name: "Rohan", cleared: meCleared, total: 5,
                           finishedAt: nil, updatedAt: .now.addingTimeInterval(-60)),
            PlayerProgress(id: "jordan", name: "Jordan", cleared: 2, total: 5,
                           finishedAt: nil, updatedAt: .now),
            PlayerProgress(id: "sam", name: "Sam", cleared: 0, total: 5,
                           finishedAt: nil, updatedAt: .now)
        ])
        return race
    }
}
