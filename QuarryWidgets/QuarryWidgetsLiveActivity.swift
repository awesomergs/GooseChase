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
            // Lock Screen / banner
            LockScreenHuntView(context: context)
                .activitySystemActionForegroundColor(.indigo)
                .widgetURL(URL(string: "quarry://camera"))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press the island)
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.checkpointIndex) of \(context.attributes.totalCheckpoints)",
                          systemImage: "flag.fill")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimer(start: context.attributes.startDate)
                        .font(.headline)
                        .foregroundStyle(.yellow)
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
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text("\(context.state.checkpointIndex)/\(context.attributes.totalCheckpoints)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: context.state.justCleared ? "checkmark.circle.fill" : "viewfinder")
                    .foregroundStyle(context.state.justCleared ? .green : .indigo)
            }
            .widgetURL(URL(string: "quarry://camera"))
            .keylineTint(.indigo)
        }
        .supplementalActivityFamilies([.small])   // Apple Watch Smart Stack layout
    }
}

/// Counts up from `start` without the app sending updates.
struct ElapsedTimer: View {
    let start: Date
    var body: some View {
        Text(timerInterval: start...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

struct LockScreenHuntView: View {
    let context: ActivityViewContext<HuntActivityAttributes>
    @Environment(\.activityFamily) private var family

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
            HStack {
                Label("\(context.state.checkpointIndex)/\(context.attributes.totalCheckpoints)",
                      systemImage: context.state.justCleared ? "checkmark.circle.fill" : "flag.fill")
                    .font(.headline)
                    .foregroundStyle(context.state.justCleared ? .green : .indigo)
                Spacer()
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: 60)
            }
            Text(context.state.clue)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(10)
    }

    /// A segment is filled once that checkpoint is cleared.
    private func isDone(_ i: Int) -> Bool {
        i < context.state.checkpointIndex || (context.state.justCleared && i == context.state.checkpointIndex)
    }

    /// iPhone Lock Screen / banner.
    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.huntTitle, systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.headline)
                    .frame(maxWidth: 70)
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
                ForEach(1...max(context.attributes.totalCheckpoints, 1), id: \.self) { i in
                    Capsule()
                        .fill(isDone(i) ? Color.indigo
                              : i == context.state.checkpointIndex ? Color.indigo.opacity(0.45)
                              : Color.secondary.opacity(0.25))
                        .frame(height: 5)
                }
            }

            Text("Checkpoint \(context.state.checkpointIndex) of \(context.attributes.totalCheckpoints)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

// MARK: - Previews (select the widget extension scheme to see these)

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
