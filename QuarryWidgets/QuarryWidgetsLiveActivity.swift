import ActivityKit
import SwiftUI
import WidgetKit

struct HuntLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuntActivityAttributes.self) { context in
            LockScreenHuntView(context: context)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "quarry://camera"))
        } dynamicIsland: { context in
            let progress = HuntProgress(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ActivityMascot(state: context.state)
                            .frame(width: 42, height: 35)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.finishedAt == nil ? "Checkpoint" : "Finished")
                                .font(.caption2)
                            Text("\(progress.current) of \(progress.total)")
                                .font(.headline)
                                .contentTransition(.numericText())
                        }
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Time").font(.caption2)
                        ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                            .font(.headline)
                            .frame(width: 84, alignment: .trailing)
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if context.state.finishedAt != nil {
                            Label("Hunt complete!", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                        } else if context.state.justCleared {
                            Label("Checkpoint \(progress.current) cleared!", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                        } else {
                            Text(context.state.clue)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if context.state.finishedAt == nil,
                           let cameraURL = URL(string: "quarry://camera") {
                            Link(destination: cameraURL) {
                                Label("Open camera", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(.black)
                                    .background(.white, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    ActivityMascot(state: context.state)
                        .frame(width: 26, height: 22)
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, alignment: .trailing)
            } minimal: {
                ActivityMascot(state: context.state)
                    .frame(width: 26, height: 22)
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(progress.cleared) of \(progress.total) checkpoints cleared")
            }
            .widgetURL(URL(string: "quarry://camera"))
            .keylineTint(.white)
        }
        .supplementalActivityFamilies([.small])
    }
}

/// Cleared progress is distinct from the checkpoint currently being searched for.
struct HuntProgress {
    let current: Int
    let total: Int
    let cleared: Int
    let justCleared: Bool

    init(context: ActivityViewContext<HuntActivityAttributes>) {
        total = max(context.attributes.totalCheckpoints, 1)
        current = min(max(context.state.checkpointIndex, 1), total)
        justCleared = context.state.justCleared
        cleared = context.state.finishedAt != nil ? total : (justCleared ? current : current - 1)
    }

    var fraction: Double { Double(cleared) / Double(total) }
    var tint: Color { .white }

    func isDone(_ i: Int) -> Bool { i <= cleared }
}

struct ProgressRing: View {
    let progress: HuntProgress
    var size: CGFloat = 16
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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


struct LockScreenHuntView: View {
    let context: ActivityViewContext<HuntActivityAttributes>
    @Environment(\.activityFamily) private var family

    private var progress: HuntProgress { HuntProgress(context: context) }
    private var successful: Bool { context.state.justCleared || context.state.finishedAt != nil }
    private var sky: Color { Color(red: 0.247, green: 0.635, blue: 0.878) }
    private var grass: Color { Color(red: 0.365, green: 0.733, blue: 0.388) }

    var body: some View {
        Group {
            if family == .small {
                watchLayout
            } else {
                phoneLayout
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        // No tint on Apple Watch: a tint there removes the Smart Stack's glass and hurts
        // readability, so the watch layout draws its own sky instead (see watchLayout).
        .activityBackgroundTint(family == .small ? nil : (successful ? grass : sky))
    }

    /// Apple Watch Smart Stack: a small sky scene. Status + timer on top, the clue big enough
    /// to read at a glance, and the goose standing on the grass with progress dots beside it.
    private var watchLayout: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(watchStatus)
                    .font(.caption2.weight(.heavy))
                    .opacity(0.9)
                    .lineLimit(1)
                Spacer(minLength: 0)
                ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .frame(width: 46, alignment: .trailing)
            }

            Group {
                if context.state.finishedAt != nil {
                    Text("Hunt complete! 🎉")
                } else if context.state.justCleared {
                    Text("Honk! Checkpoint cleared")
                } else {
                    Text(context.state.clue)
                }
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 6) {
                ActivityMascot(state: context.state)
                    .frame(width: 46, height: 38)
                    .padding(.bottom, 5)      // feet on the grass line
                Spacer(minLength: 0)
                if progress.total <= 8 {
                    HStack(spacing: 3) {
                        ForEach(1...progress.total, id: \.self) { checkpoint in
                            Capsule()
                                .fill(.white.opacity(progress.isDone(checkpoint) ? 1 : 0.35))
                                .frame(width: 9, height: 5)
                        }
                    }
                    .padding(.bottom, 16)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(progress.cleared) of \(progress.total) checkpoints cleared")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: successful
                    ? [Color(red: 0.20, green: 0.53, blue: 0.29), grass]
                    : [Color(red: 0.16, green: 0.48, blue: 0.71), sky],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(alignment: .bottom) {
                ActivityGrass()
                    .fill(successful ? Color(red: 0.20, green: 0.53, blue: 0.29) : grass)
                    .frame(height: 16)
            }
            .clipShape(ContainerRelativeShape())
        }
    }

    private var watchStatus: String {
        if context.state.finishedAt != nil { return "FINISHED" }
        return "CHECKPOINT \(progress.current) OF \(progress.total)"
    }

    private var phoneLayout: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ActivityMascot(state: context.state)
                .frame(width: 84, height: 70)
                // The drawing's grounded foot is 9% above its bottom edge.
                // This offset places that foot on the grass at y = height - 22.
                .offset(y: 6.3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(context.attributes.huntTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    ElapsedTimer(start: context.attributes.startDate, end: context.state.finishedAt)
                        .font(.subheadline.bold())
                        .frame(width: 72, alignment: .trailing)
                }

                if context.state.finishedAt != nil {
                    Label("Hunt complete!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                } else if context.state.justCleared {
                    Label("Checkpoint \(progress.current) cleared!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                } else {
                    Text("Checkpoint \(progress.current) of \(progress.total)")
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text(context.state.clue)
                        .font(.caption)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    progressBar
                    if context.state.finishedAt == nil {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background {
            LinearGradient(
                colors: successful
                    ? [Color(red: 0.20, green: 0.53, blue: 0.29), grass]
                    : [Color(red: 0.16, green: 0.48, blue: 0.71), sky],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(alignment: .bottom) {
                ActivityGrass().fill(grass).frame(height: 30)
            }
        }
    }

    private var progressBar: some View {
        Group {
            if progress.total <= 12 {
                HStack(spacing: 4) {
                    ForEach(1...progress.total, id: \.self) { checkpoint in
                        Capsule()
                            .fill(.white.opacity(progress.isDone(checkpoint) ? 1 : 0.25))
                            .frame(height: 6)
                    }
                }
            } else {
                ProgressView(value: progress.fraction)
                    .tint(.white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.cleared) of \(progress.total) checkpoints cleared")
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
