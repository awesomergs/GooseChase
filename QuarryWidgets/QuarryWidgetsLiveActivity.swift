//
//  QuarryWidgetsLiveActivity.swift  ·  OWNER: Person C (Live Activity)
//  Lock Screen, Dynamic Island, and the Apple Watch Smart Stack (.small family).
//  Switch the scheme to QuarryWidgetsExtension to see the previews at the bottom.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct HuntLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuntActivityAttributes.self) { context in
            // Lock Screen / banner / Watch Smart Stack
            LockScreenHuntView(context: context)
                .activitySystemActionForegroundColor(.indigo)
                .widgetURL(URL(string: "quarry://camera"))

        } dynamicIsland: { context in
            let progress = HuntProgress(context: context)

            return DynamicIsland {
                // MARK: Expanded (long-press the island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ProgressRing(progress: progress, size: 30, lineWidth: 4)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Checkpoint")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(progress.current) of \(progress.total)")
                                .font(.headline)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Time")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                            .font(.headline)
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: 72, alignment: .trailing)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if context.state.justCleared {
                            Label(context.state.clue, systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else {
                            Text(context.state.clue)
                                .font(.body.weight(.semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: URL(string: "quarry://camera")!) {
                            Label("Open camera", systemImage: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.indigo, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }

            // MARK: Compact (island at rest)
            } compactLeading: {
                HStack(spacing: 5) {
                    ProgressRing(progress: progress, size: 16, lineWidth: 3)
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.tint)
                }
            } compactTrailing: {
                ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .frame(width: 42, alignment: .trailing)

            // MARK: Minimal (sharing the island with another activity)
            } minimal: {
                // Ring = share of checkpoints cleared; inside = the checkpoint you're on.
                ZStack {
                    ProgressRing(progress: progress, size: 24, lineWidth: 3)
                    if context.state.justCleared {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(progress.current)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
            .widgetURL(URL(string: "quarry://camera"))
            .keylineTint(.indigo)
        }
        .supplementalActivityFamilies([.small])   // Apple Watch Smart Stack layout
    }
}

// MARK: - Shared pieces

/// Derived progress numbers, shared by every presentation.
struct HuntProgress {
    let current: Int      // 1-based checkpoint being shown
    let total: Int
    let cleared: Int      // how many checkpoints are done
    let justCleared: Bool

    init(context: ActivityViewContext<HuntActivityAttributes>) {
        current = context.state.checkpointIndex
        total = max(context.attributes.totalCheckpoints, 1)
        justCleared = context.state.justCleared
        cleared = justCleared ? current : current - 1
    }

    var fraction: Double { Double(cleared) / Double(total) }
    var tint: Color { justCleared ? .green : .indigo }

    /// A progress-bar segment (1-based) is filled once that checkpoint is cleared.
    func isDone(_ i: Int) -> Bool { i <= cleared }
}

/// Small circular progress ring.
struct ProgressRing: View {
    let progress: HuntProgress
    var size: CGFloat = 16
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress.fraction, 0.04))
                .stroke(progress.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(progress.cleared) of \(progress.total) checkpoints cleared")
    }
}

/// Counts up from `start` without the app sending updates.
/// Once `end` is set (hunt complete), shows the fixed final time instead.
struct ElapsedTimer: View {
    let start: Date
    var end: Date? = nil

    var body: some View {
        if let end {
            Text(Self.format(end.timeIntervalSince(start)))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Lock Screen / Watch

struct LockScreenHuntView: View {
    let context: ActivityViewContext<HuntActivityAttributes>
    @Environment(\.activityFamily) private var family

    private var progress: HuntProgress { HuntProgress(context: context) }

    var body: some View {
        if family == .small {
            watchLayout
        } else {
            phoneLayout
        }
    }

    /// Apple Watch Smart Stack (and CarPlay): small and glanceable.
    private var watchLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressRing(progress: progress, size: 18, lineWidth: 3)
                Text("\(progress.current)/\(progress.total)")
                    .font(.headline)
                    .foregroundStyle(progress.tint)
                Spacer()
                ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: 60, alignment: .trailing)
            }
            Text(context.state.clue)
                .font(.caption)
                .foregroundStyle(context.state.justCleared ? .green : .primary)
                .lineLimit(2)
        }
        .padding(10)
    }

    /// iPhone Lock Screen / banner.
    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.huntTitle, systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                    .font(.headline)
                    .frame(maxWidth: 70, alignment: .trailing)
            }

            if context.state.justCleared {
                Label(context.state.clue, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Text(context.state.clue)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Segmented progress bar
            HStack(spacing: 4) {
                ForEach(1...progress.total, id: \.self) { i in
                    Capsule()
                        .fill(progress.isDone(i) ? Color.indigo
                              : i == progress.current ? Color.indigo.opacity(0.45)
                              : Color.secondary.opacity(0.25))
                        .frame(height: 5)
                }
            }

            Text("Checkpoint \(progress.current) of \(progress.total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

// MARK: - Previews (select the QuarryWidgetsExtension scheme to see these)

#Preview("Lock Screen", as: .content, using: HuntActivityAttributes.preview) {
    HuntLiveActivity()
} contentStates: {
    HuntActivityAttributes.ContentState.searching
    HuntActivityAttributes.ContentState.cleared
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: HuntActivityAttributes.preview) {
    HuntLiveActivity()
} contentStates: {
    HuntActivityAttributes.ContentState.searching
    HuntActivityAttributes.ContentState.cleared
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: HuntActivityAttributes.preview) {
    HuntLiveActivity()
} contentStates: {
    HuntActivityAttributes.ContentState.searching
}

#Preview("Island minimal", as: .dynamicIsland(.minimal), using: HuntActivityAttributes.preview) {
    HuntLiveActivity()
} contentStates: {
    HuntActivityAttributes.ContentState.searching
}
