//
//  HuntSession.swift  ·  OWNER: Person B (hunt flow)
//  Tracks the hunt being played, records per-checkpoint split times, and keeps the
//  Live Activity in sync. The only caller of LiveActivityManager.
//

import Foundation
import Observation

@Observable
final class HuntSession {
    let hunt: Hunt
    private(set) var currentIndex = 0          // 0-based into hunt.orderedCheckpoints
    private(set) var startDate = Date.now
    private(set) var isFinished = false

    /// One split per cleared checkpoint, in order (seconds spent on that checkpoint).
    private(set) var splits: [TimeInterval] = []
    /// 1-based number of the most recently cleared checkpoint (for the cleared screen).
    private(set) var lastClearedNumber = 0
    /// True between clearing a checkpoint and advancing off it; drives the cleared screen
    /// and guards `advance()` so the button tap and the 3s timer can't both move forward.
    private(set) var isAwaitingAdvance = false

    private var lastClearDate = Date.now
    private var advanceTask: Task<Void, Never>?

    init(hunt: Hunt) { self.hunt = hunt }

    var checkpoints: [Checkpoint] { hunt.orderedCheckpoints }
    var current: Checkpoint? { checkpoints.indices.contains(currentIndex) ? checkpoints[currentIndex] : nil }
    var progressText: String { "\(min(currentIndex + 1, checkpoints.count)) of \(checkpoints.count)" }
    /// Time spent on the most recently cleared checkpoint.
    var lastSplit: TimeInterval? { splits.last }
    /// Total play time (sum of all splits); frozen once the hunt finishes.
    var totalTime: TimeInterval { splits.reduce(0, +) }

    func start() {
        advanceTask?.cancel()
        advanceTask = nil
        isAwaitingAdvance = false
        currentIndex = 0
        startDate = .now
        lastClearDate = .now
        isFinished = false
        splits = []
        lastClearedNumber = 0
        LiveActivityManager.shared.start(
            huntTitle: hunt.title,
            totalCheckpoints: checkpoints.count,
            firstClue: current?.clue ?? ""
        )
    }

    /// Call when Vision clears the current checkpoint. Records the split, pops the Live
    /// Activity open, and arms a 3-second auto-advance. The "Next clue"/"Finish" button
    /// calls `advance()` sooner; whichever fires first wins (see `isAwaitingAdvance`).
    func clearCurrent() {
        let now = Date.now
        splits.append(now.timeIntervalSince(lastClearDate))
        lastClearDate = now
        lastClearedNumber = currentIndex + 1
        isAwaitingAdvance = true

        let cleared = lastClearedNumber
        let clue = current?.clue ?? ""
        Task { await LiveActivityManager.shared.cleared(index: cleared, clue: clue) }

        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    /// Move to the next checkpoint (or finish). Runs at most once per cleared checkpoint,
    /// so a button tap and the 3-second timer can't skip two checkpoints.
    func advance() {
        guard isAwaitingAdvance else { return }
        isAwaitingAdvance = false
        advanceTask?.cancel()
        advanceTask = nil

        currentIndex += 1

        // After advancing, currentIndex equals the number of checkpoints cleared (0-based index
        // now points to the NEXT checkpoint, so its value == cleared count). Report to the race.
        if RaceSession.shared.isActive {
            RaceSession.shared.reportProgress(cleared: currentIndex, total: checkpoints.count)
        }

        if let next = current {
            Task { await LiveActivityManager.shared.advance(to: currentIndex + 1, clue: next.clue) }
        } else {
            isFinished = true
            Task { await LiveActivityManager.shared.end() }
        }
    }

    func quit() {
        advanceTask?.cancel()
        advanceTask = nil
        isAwaitingAdvance = false
        Task { await LiveActivityManager.shared.end(finalMessage: "Hunt ended") }
    }
}
