//
//  HuntPackageTests.swift  ·  GooseChaseTests
//  HuntPackage / CheckpointPackage (GooseChase/Shared/HuntPackage.swift) and NearbyMessage
//  (GooseChase/Shared/RaceMessages.swift): the wire formats sent over AirDrop (.quarryhunt files)
//  and MultipeerConnectivity. A change that breaks these round-trips breaks joining between
//  phones on different builds. Pure Codable tests: no SwiftData, no networking.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import GooseChase

@MainActor
@Suite("HuntPackage wire format")
struct HuntPackageTests {

    static func sample() -> HuntPackage {
        HuntPackage(
            shareID: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!,
            title: "Birthday Hunt",
            hostName: "Rohan",
            checkpoints: [
                CheckpointPackage(
                    order: 0,
                    clue: "Find the thing that keeps the milk cold.",
                    kindRaw: "exactMatch",
                    referencePrints: [Data([0x01, 0x02, 0x03]), Data(repeating: 0xAB, count: 64)],
                    thumbnail: Data([0xFF, 0xD8, 0xFF]),
                    targetLabel: nil,
                    latitude: nil,
                    longitude: nil,
                    radiusMeters: 40,
                    requiresLocation: false
                ),
                CheckpointPackage(
                    order: 1,
                    clue: "Find something with wheels 🛞 — \"quotes\" & ünïcödé",
                    kindRaw: "object",
                    referencePrints: [],
                    thumbnail: nil,
                    targetLabel: "wheel",
                    latitude: 34.0224,
                    longitude: -118.2851,
                    radiusMeters: 25.5,
                    requiresLocation: true
                )
            ]
        )
    }

    @Test("formatVersion defaults to 1")
    func formatVersionDefault() {
        #expect(Self.sample().formatVersion == 1)
    }

    @Test("JSON encode → decode round-trips every field")
    func jsonRoundTrip() throws {
        let original = Self.sample()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HuntPackage.self, from: data)
        #expect(decoded == original)
        #expect(decoded.checkpoints.map(\.order) == [0, 1])
        #expect(decoded.checkpoints[0].referencePrints == original.checkpoints[0].referencePrints)
        #expect(decoded.checkpoints[1].latitude == 34.0224)
        #expect(decoded.checkpoints[1].clue == original.checkpoints[1].clue)
    }

    @Test("an empty hunt round-trips")
    func emptyHuntRoundTrip() throws {
        let empty = HuntPackage(shareID: UUID(), title: "", hostName: "", checkpoints: [])
        let decoded = try JSONDecoder().decode(HuntPackage.self, from: JSONEncoder().encode(empty))
        #expect(decoded == empty)
    }

    @Test("load(from:) reads a .quarryhunt file written as JSON")
    func loadFromFile() throws {
        let original = Self.sample()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("quarryhunt")
        try JSONEncoder().encode(original).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try HuntPackage.load(from: url) == original)
    }

    @Test("load(from:) throws on a file that isn't a hunt")
    func loadFromGarbage() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("quarryhunt")
        try Data("not a hunt".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: (any Error).self) { try HuntPackage.load(from: url) }
    }

    @Test("UTType.quarryHunt keeps its identifier (Info.plist declares com.quarryapp.hunt)")
    func utTypeIdentifier() {
        // Keep this identifier through the GooseChase rename, or older .quarryhunt files stop opening.
        #expect(UTType.quarryHunt.identifier == "com.quarryapp.hunt")
    }
}

@MainActor
@Suite("NearbyMessage wire format")
struct NearbyMessageTests {

    static let player = PlayerProgress(
        id: "B8E3A1F2-0000-4000-8000-000000000001",
        name: "Maya",
        cleared: 2,
        total: 5,
        finishedAt: nil,
        updatedAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
    )

    private func roundTrip(_ message: NearbyMessage) throws -> NearbyMessage {
        try NearbyMessage.decode(message.encoded())
    }

    @Test(".hello round-trips")
    func hello() throws {
        guard case .hello(let p) = try roundTrip(.hello(player: Self.player)) else {
            Issue.record("decoded to a different case"); return
        }
        #expect(p == Self.player)
    }

    @Test(".hunt round-trips")
    func hunt() throws {
        let package = HuntPackageTests.sample()
        guard case .hunt(let decoded) = try roundTrip(.hunt(package)) else {
            Issue.record("decoded to a different case"); return
        }
        #expect(decoded == package)
    }

    @Test(".start(at:) round-trips the exact start time")
    func start() throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_123.25)
        guard case .start(let decoded) = try roundTrip(.start(at: date)) else {
            Issue.record("decoded to a different case"); return
        }
        #expect(decoded == date)
    }

    @Test(".progress and .leaderboard round-trip")
    func progressAndLeaderboard() throws {
        var finished = Self.player
        finished.id = "other"
        finished.cleared = 5
        finished.finishedAt = Date(timeIntervalSinceReferenceDate: 800_000_500)

        guard case .progress(let p) = try roundTrip(.progress(finished)) else {
            Issue.record("decoded to a different case"); return
        }
        #expect(p == finished)

        guard case .leaderboard(let list) = try roundTrip(.leaderboard([finished, Self.player])) else {
            Issue.record("decoded to a different case"); return
        }
        #expect(list == [finished, Self.player])
    }

    @Test("decode rejects garbage")
    func garbage() {
        #expect(throws: (any Error).self) { try NearbyMessage.decode(Data("{}".utf8)) }
        #expect(throws: (any Error).self) { try NearbyMessage.decode(Data()) }
    }
}
