//
//  VisionMatcherScoreTests.swift  ·  GooseChaseTests
//  VisionMatcher.score(forDistance:strong:weak:) (Quarry/Vision/VisionMatcher.swift):
//  maps a feature-print distance to the 0...1 match score shown on the camera ring.
//  Defaults: strong = 0.45 (score 1), weak = 1.0 (score 0), linear in between.
//  CameraCaptureView clears at score >= 0.85, i.e. distance <= 0.5325.
//  No camera or images needed: score(forDistance:) is pure.
//

import Foundation
import Testing
@testable import Quarry

@MainActor
@Suite("VisionMatcher.score(forDistance:)")
struct VisionMatcherScoreTests {

    /// Mirrors `matchThreshold` in CameraCaptureView.swift (private there).
    static let clearThreshold = 0.85
    static let strong: Float = 0.45
    static let weak: Float = 1.0

    @Test("distances at or below `strong` score 1", arguments: [Float(0), 0.1, 0.3, 0.45])
    func strongMatches(distance: Float) {
        #expect(VisionMatcher.score(forDistance: distance) == 1)
    }

    @Test("distances at or above `weak` score 0", arguments: [Float(1.0), 1.2, 5, 100])
    func weakMatches(distance: Float) {
        #expect(VisionMatcher.score(forDistance: distance) == 0)
    }

    @Test("no references (greatestFiniteMagnitude from bestDistance) scores 0")
    func noReferences() {
        #expect(VisionMatcher.score(forDistance: .greatestFiniteMagnitude) == 0)
    }

    @Test("midpoint between strong and weak scores 0.5")
    func midpoint() {
        let mid = (Self.strong + Self.weak) / 2   // 0.725
        #expect(abs(VisionMatcher.score(forDistance: mid) - 0.5) < 1e-6)
    }

    @Test("score stays within 0...1 and never increases as distance grows")
    func boundedAndMonotonic() {
        var previous = Double.infinity
        for step in 0...400 {
            let d = Float(step) * 0.005          // 0.0 ... 2.0
            let s = VisionMatcher.score(forDistance: d)
            #expect((0...1).contains(s), "score \(s) out of bounds at d = \(d)")
            #expect(s <= previous + 1e-12, "score increased at d = \(d)")
            previous = s
        }
    }

    @Test("the clear threshold 0.85 sits at distance 0.5325")
    func clearThresholdDistance() {
        // score = (weak - d) / (weak - strong)  =>  d = weak - 0.85 * (weak - strong)
        let boundary = Self.weak - Float(Self.clearThreshold) * (Self.weak - Self.strong)
        #expect(abs(boundary - 0.5325) < 1e-5)
        #expect(abs(VisionMatcher.score(forDistance: boundary) - Self.clearThreshold) < 1e-4)
        #expect(VisionMatcher.score(forDistance: 0.52) >= Self.clearThreshold)  // just inside: clears
        #expect(VisionMatcher.score(forDistance: 0.55) < Self.clearThreshold)   // just outside: doesn't
    }

    @Test("custom strong/weak thresholds are respected")
    func customThresholds() {
        #expect(VisionMatcher.score(forDistance: 0.2, strong: 0.2, weak: 0.6) == 1)
        #expect(VisionMatcher.score(forDistance: 0.6, strong: 0.2, weak: 0.6) == 0)
        #expect(abs(VisionMatcher.score(forDistance: 0.4, strong: 0.2, weak: 0.6) - 0.5) < 1e-6)
    }

    @Test("NaN distance scores 0")
    func nanDistance() {
        #expect(VisionMatcher.score(forDistance: .nan) == 0)
    }
}
