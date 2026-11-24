//
//  HelperTests.swift  ·  GooseChaseTests
//  Small pure helpers: mmss(_:) and ordinal(_:) (module-level, in GooseChase/Hunt/PlayView.swift),
//  CheckpointKind raw values, and the Live Activity ContentState size budget.
//

import Foundation
import Testing
@testable import GooseChase

@MainActor
@Suite("Time and rank formatting")
struct FormattingTests {

    @Test("mmss formats seconds as m:ss", arguments: [
        (0.0, "0:00"),
        (5.0, "0:05"),
        (59.4, "0:59"),
        (59.5, "1:00"),     // rounds to the nearest second
        (61.0, "1:01"),
        (600.0, "10:00"),
        (3599.0, "59:59"),
        (3600.0, "60:00")   // no hours: minutes keep counting
    ])
    func mmssFormatting(seconds: Double, expected: String) {
        #expect(mmss(seconds) == expected)
    }

    @Test("ordinal adds st/nd/rd/th, with 11–13 as th", arguments: [
        (1, "1st"), (2, "2nd"), (3, "3rd"), (4, "4th"), (10, "10th"),
        (11, "11th"), (12, "12th"), (13, "13th"),
        (21, "21st"), (22, "22nd"), (23, "23rd"), (24, "24th"),
        (101, "101st"), (111, "111th"), (112, "112th"), (113, "113th"), (0, "0th")
    ])
    func ordinalSuffix(n: Int, expected: String) {
        #expect(ordinal(n) == expected)
    }
}

@MainActor
@Suite("CheckpointKind")
struct CheckpointKindTests {

    @Test("raw values are stable (they are stored in SwiftData and sent in HuntPackage.kindRaw)")
    func rawValues() {
        #expect(CheckpointKind.exactMatch.rawValue == "exactMatch")
        #expect(CheckpointKind.object.rawValue == "object")
        #expect(CheckpointKind.allCases.count == 2)
        #expect(CheckpointKind(rawValue: "somethingNew") == nil)
    }
}

@MainActor
@Suite("Live Activity content state")
struct ActivityContentStateTests {
    // Only Codable is exercised here: no ActivityKit request is made.

    @Test("ContentState round-trips through JSON")
    func roundTrip() throws {
        let state = HuntActivityAttributes.ContentState(
            checkpointIndex: 3,
            clue: "Find the thing that keeps the milk cold.",
            justCleared: true,
            finishedAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
        )
        let decoded = try JSONDecoder().decode(
            HuntActivityAttributes.ContentState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(decoded == state)
    }

    @Test("a long clue stays well under ActivityKit's 4 KB payload limit")
    func payloadBudget() throws {
        let longClue = String(repeating: "Look under the third bench past the fountain. ", count: 10) // ~470 chars
        let state = HuntActivityAttributes.ContentState(checkpointIndex: 12, clue: longClue, justCleared: false)
        let bytes = try JSONEncoder().encode(state).count
        #expect(bytes < 4096, "ContentState encodes to \(bytes) bytes")
    }
}
