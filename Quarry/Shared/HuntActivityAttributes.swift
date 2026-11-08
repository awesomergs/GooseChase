//
//  HuntActivityAttributes.swift  ·  SHARED by the app AND the QuarryWidgetsExtension target
//  (already set up in the project file; don't move this file).
//

import ActivityKit
import Foundation

nonisolated struct HuntActivityAttributes: ActivityAttributes {
    /// Changes during the hunt. Keep it small (< 4 KB).
    nonisolated struct ContentState: Codable, Hashable {
        var checkpointIndex: Int      // 1-based: "3 of 8"
        var clue: String
        var justCleared: Bool         // true briefly after a clear, for the success state
        var finishedAt: Date? = nil   // set when the hunt is complete: timers freeze at this time
    }

    /// Fixed for the whole hunt.
    var huntTitle: String
    var totalCheckpoints: Int
    var startDate: Date
}

// Sample data for Xcode previews
extension HuntActivityAttributes {
    static var preview: HuntActivityAttributes {
        .init(huntTitle: "Birthday Hunt", totalCheckpoints: 5, startDate: .now.addingTimeInterval(-372))
    }
}

extension HuntActivityAttributes.ContentState {
    static var searching: Self {
        .init(checkpointIndex: 3, clue: "Find the thing that keeps the milk cold.", justCleared: false)
    }
    static var cleared: Self {
        .init(checkpointIndex: 3, clue: "Find the thing that keeps the milk cold.", justCleared: true)
    }
}
