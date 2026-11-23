//
//  RaceSessionTests.swift  ·  GooseChaseTests
//  Pure parts of the (currently dormant) live leaderboard in Quarry/Race/.
//  Only static functions are used, so RaceSession.shared is never created.
//  If you delete Quarry/Race (docs/phase0/DEAD_CODE.md, Option B), delete this file too.
//

import Foundation
import Testing
@testable import Quarry

@MainActor
@Suite("RaceSession standings")
struct RaceSessionTests {

    static let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static func player(_ id: String, cleared: Int, finishedAfter: TimeInterval? = nil,
                       updatedAfter: TimeInterval = 0) -> PlayerProgress {
        PlayerProgress(id: id, name: id, cleared: cleared, total: 5,
                       finishedAt: finishedAfter.map { Self.t0.addingTimeInterval($0) },
                       updatedAt: Self.t0.addingTimeInterval(updatedAfter))
    }

    @Test("finished players rank first, earliest finish wins")
    func finishedFirst() {
        let sorted = RaceSession.sorted([
            Self.player("still-going", cleared: 4),
            Self.player("slow-finish", cleared: 5, finishedAfter: 900),
            Self.player("fast-finish", cleared: 5, finishedAfter: 600)
        ])
        #expect(sorted.map(\.id) == ["fast-finish", "slow-finish", "still-going"])
    }

    @Test("unfinished players: more cleared first, then whoever got there first")
    func unfinishedOrder() {
        let sorted = RaceSession.sorted([
            Self.player("two-late", cleared: 2, updatedAfter: 300),
            Self.player("zero", cleared: 0),
            Self.player("three", cleared: 3, updatedAfter: 500),
            Self.player("two-early", cleared: 2, updatedAfter: 100)
        ])
        #expect(sorted.map(\.id) == ["three", "two-early", "two-late", "zero"])
    }

    @Test("sorting an empty list is fine")
    func empty() {
        #expect(RaceSession.sorted([]).isEmpty)
    }

    @Test("LeaderboardRow.format matches mmss (duplicate helper)")
    func formatMatchesMMSS() {
        for seconds in [0.0, 42.0, 59.5, 61.0, 702.0, 3600.0] {
            #expect(LeaderboardRow.format(seconds) == mmss(seconds))
        }
    }
}
