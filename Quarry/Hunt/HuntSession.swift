//
//  HuntSession.swift  ·  OWNER: Person B (hunt flow)
//  Tracks the hunt being played and keeps the Live Activity in sync.
//

import Foundation
import Observation

@Observable
final class HuntSession {
    let hunt: Hunt
    private(set) var currentIndex = 0          // 0-based into hunt.orderedCheckpoints
    private(set) var startDate = Date.now
    private(set) var isFinished = false

    init(hunt: Hunt) { self.hunt = hunt }

    var checkpoints: [Checkpoint] { hunt.orderedCheckpoints }
    var current: Checkpoint? { checkpoints.indices.contains(currentIndex) ? checkpoints[currentIndex] : nil }
    var progressText: String { "\(min(currentIndex + 1, checkpoints.count)) of \(checkpoints.count)" }

    func start() {
        currentIndex = 0
        startDate = .now
        isFinished = false
        LiveActivityManager.shared.start(
            huntTitle: hunt.title,
            totalCheckpoints: checkpoints.count,
            firstClue: current?.clue ?? ""
        )
    }

    /// Call when Vision clears the current checkpoint.
    func clearCurrent() {
        let clearedNumber = currentIndex + 1
        let clue = current?.clue ?? ""
        currentIndex += 1

        Task {
            await LiveActivityManager.shared.cleared(index: clearedNumber, clue: clue)
            try? await Task.sleep(for: .seconds(3))
            if let next = current {
                await LiveActivityManager.shared.advance(to: currentIndex + 1, clue: next.clue)
            } else {
                isFinished = true
                await LiveActivityManager.shared.end()
            }
        }
    }

    func quit() {
        Task { await LiveActivityManager.shared.end(finalMessage: "Hunt ended") }
    }
}
