//
//  LiveActivityManager.swift  ·  OWNER: Person C (Live Activity)
//  HuntSession calls start / cleared / advance / end. Nobody else needs to touch this.

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// How long the finished hunt stays on the Lock Screen / island before iOS removes it.
    private let finishedLingerTime: TimeInterval = 3 * 60
    private var activity: Activity<HuntActivityAttributes>?

    /// Call when the player taps Start.
    func start(huntTitle: String, totalCheckpoints: Int, firstClue: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are off: Settings > [App] > Live Activities")
            return
        }
        let attributes = HuntActivityAttributes(
            huntTitle: huntTitle,
            totalCheckpoints: totalCheckpoints,
            startDate: .now
        )
        let state = HuntActivityAttributes.ContentState(
            checkpointIndex: 1, clue: firstClue, justCleared: false
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
                // no pushType: local updates only (works with a free Personal Team)
            )
        } catch {
            print("⚠️ Live Activity failed to start:", error)
        }
    }

    /// Call right after Vision clears a checkpoint.
    /// Note: iOS hides an app's own Live Activity while that app is on screen, and the
    /// alert only expands the island when the app is in the background. Since clears happen
    /// in-app, users mostly see the result after leaving the app (green "cleared" state).
    func cleared(index: Int, clue: String) async {
        guard let activity else { return }
        // The views show `clue` as the status line while justCleared is true.
        let total = activity.attributes.totalCheckpoints
        let message = index < total ? "Checkpoint \(index) cleared!" : "Last checkpoint cleared!"
        let state = HuntActivityAttributes.ContentState(checkpointIndex: index, clue: message, justCleared: true)
        await activity.update(
            .init(state: state, staleDate: nil),
            alertConfiguration: AlertConfiguration(
                title: "Checkpoint cleared!",
                body: "Next clue unlocked",
                sound: .default
            )
        )
    }

    /// Call when the next clue is shown.
    func advance(to index: Int, clue: String) async {
        guard let activity else { return }
        let state = HuntActivityAttributes.ContentState(checkpointIndex: index, clue: clue, justCleared: false)
        await activity.update(.init(state: state, staleDate: nil))
    }

    /// Call when the hunt is finished or abandoned.
    func end(finalMessage: String = "Hunt complete!") async {
        guard let activity else { return }
        let final = HuntActivityAttributes.ContentState(
            checkpointIndex: activity.attributes.totalCheckpoints,
            clue: finalMessage,
            justCleared: true
        )
        await activity.end(.init(state: final, staleDate: nil), dismissalPolicy: .after(.now.addingTimeInterval(finishedLingerTime)))
        self.activity = nil
    }

    /// Handy while testing: kills any leftover activities from earlier runs.
    func endAllStale() async {
        for a in Activity<HuntActivityAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
    }
}
