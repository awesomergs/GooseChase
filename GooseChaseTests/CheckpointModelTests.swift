//
//  CheckpointModelTests.swift  ·  GooseChaseTests
//  Computed properties on the SwiftData Checkpoint model (GooseChase/Shared/Models.swift).
//  These create @Model objects WITHOUT a ModelContainer and never touch relationships,
//  which SwiftData allows for plain attribute access. If they ever crash on a newer SDK
//  ("no container" style traps), wrap them in an in-memory ModelContainer or delete this file;
//  nothing else depends on it.
//

import CoreLocation
import Foundation
import Testing
@testable import GooseChase

@MainActor
@Suite("Checkpoint model")
struct CheckpointModelTests {

    @Test("exactMatch is ready only once it has a reference print")
    func exactMatchReadiness() {
        let cp = Checkpoint(order: 0, clue: "Find the blue cup.", kind: .exactMatch)
        #expect(!cp.isReady)
        cp.referencePrints = [Data([0x01])]
        #expect(cp.isReady)
    }

    @Test("object is ready only with a non-empty target label")
    func objectReadiness() {
        let cp = Checkpoint(order: 0, clue: "Find something with wheels.", kind: .object)
        #expect(!cp.isReady)
        cp.targetLabel = ""
        #expect(!cp.isReady)
        cp.targetLabel = "wheel"
        #expect(cp.isReady)
        // Note: the camera only verifies feature prints today, so a "ready" object checkpoint
        // can't actually be cleared yet (see docs/phase0/ISSUES.md, Phase 1).
    }

    @Test("kind maps to and from kindRaw; unknown raw values fall back to exactMatch")
    func kindMapping() {
        let cp = Checkpoint(order: 0, clue: "", kind: .object)
        #expect(cp.kindRaw == "object")
        cp.kind = .exactMatch
        #expect(cp.kindRaw == "exactMatch")
        cp.kindRaw = "fromTheFuture"
        #expect(cp.kind == .exactMatch)
    }

    @Test("coordinate needs both latitude and longitude")
    func coordinate() {
        let cp = Checkpoint(order: 0, clue: "", kind: .exactMatch)
        #expect(cp.coordinate == nil)
        cp.latitude = 34.0224
        #expect(cp.coordinate == nil)
        cp.coordinate = CLLocationCoordinate2D(latitude: 34.0224, longitude: -118.2851)
        #expect(cp.latitude == 34.0224)
        #expect(cp.longitude == -118.2851)
        #expect(cp.coordinate?.longitude == -118.2851)
        cp.coordinate = nil
        #expect(cp.latitude == nil && cp.longitude == nil)
    }

    @Test("location defaults: 40 m radius, not required")
    func locationDefaults() {
        let cp = Checkpoint(order: 0, clue: "", kind: .exactMatch)
        #expect(cp.radiusMeters == 40)
        #expect(cp.requiresLocation == false)
    }
}
