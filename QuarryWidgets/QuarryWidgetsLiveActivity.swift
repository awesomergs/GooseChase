//
//  QuarryWidgetsLiveActivity.swift  ·  OWNER: Person C (Live Activity)
//  Lock Screen, Dynamic Island, and the Apple Watch Smart Stack (.small family).
//  Switch the scheme to QuarryWidgetsExtension to see the previews at the bottom.
//

import ActivityKit
import SwiftUI
import WidgetKit


/// Mirrors the app palette because the extension has separate target membership.
private struct ActivityTheme {
    let colorScheme: ColorScheme

    var canvas: Color { color(light: 0xFFF9F0, dark: 0x1D1916) }
    var card: Color { color(light: 0xFFFEFB, dark: 0x2B2520) }
    var accent: Color { color(light: 0xC45118, dark: 0xFFAB70) }
    var sand: Color { color(light: 0xFFF0DF, dark: 0x49392C) }
    var primaryText: Color { color(light: 0x2D2925, dark: 0xFFF9F0) }
    var secondaryText: Color { color(light: 0x746B63, dark: 0xC2B3A5) }
    var verified: Color { color(light: 0x2F6B4F, dark: 0x8EC9A5) }
    var onAccent: Color { color(light: 0xFFFEFB, dark: 0x2D2925) }

    static let relatedSpacing: CGFloat = 8
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let thumbnailRadius: CGFloat = 12
    static let thumbnailSize: CGFloat = 56
    static let heading: Font = .system(.headline, design: .rounded).bold()

    private func color(light: UInt32, dark: UInt32) -> Color {
        let hex = colorScheme == .dark ? dark : light
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct HuntLiveActivity: Widget {
    private let islandTheme = ActivityTheme(colorScheme: .dark)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuntActivityAttributes.self) { context in
            // Lock Screen / banner / Watch Smart Stack
            LockScreenHuntView(context: context)
                .activitySystemActionForegroundColor(ActivityTheme(colorScheme: .light).accent)
                .widgetURL(URL(string: "quarry://camera"))

        } dynamicIsland: { context in
            let progress = HuntProgress(context: context)

            return DynamicIsland {
                // MARK: Expanded (long-press the island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ProgressRing(progress: progress, size: 30, lineWidth: 4)
                            .environment(\.colorScheme, .dark)
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
                        ElapsedTimer(start: context.attributes.startDate)
                            .font(.headline)
                            .foregroundStyle(islandTheme.secondaryText)
                            .frame(maxWidth: 72, alignment: .trailing)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if context.state.justCleared {
                            Label(context.state.clue, systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(islandTheme.verified)
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
                                .background(islandTheme.accent, in: .capsule)
                                .foregroundStyle(islandTheme.onAccent)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }

            // MARK: Compact (island at rest)
            } compactLeading: {
                HStack(spacing: 5) {
                    ProgressRing(progress: progress, size: 16, lineWidth: 3)
                        .environment(\.colorScheme, .dark)
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.tint)
                }
            } compactTrailing: {
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(islandTheme.secondaryText)
                    .frame(width: 42, alignment: .trailing)

            // MARK: Minimal (sharing the island with another activity)
            } minimal: {
                // Ring = share of checkpoints cleared; inside = the checkpoint you're on.
                ZStack {
                    ProgressRing(progress: progress, size: 24, lineWidth: 3)
                        .environment(\.colorScheme, .dark)
                    if context.state.justCleared {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(islandTheme.verified)
                    } else {
                        Text("\(progress.current)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
            .widgetURL(URL(string: "quarry://camera"))
            .keylineTint(islandTheme.accent)
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
    var tint: Color { justCleared ? ActivityTheme(colorScheme: .dark).verified : ActivityTheme(colorScheme: .dark).accent }

    /// A progress-bar segment (1-based) is filled once that checkpoint is cleared.
    func isDone(_ i: Int) -> Bool { i <= cleared }
}

/// Small circular progress ring.
struct ProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ActivityTheme { ActivityTheme(colorScheme: colorScheme) }
    let progress: HuntProgress
    var size: CGFloat = 16
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.secondaryText.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress.fraction, 0.04))
                .stroke(progress.justCleared ? theme.verified : theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(progress.cleared) of \(progress.total) checkpoints cleared")
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

// MARK: - Lock Screen / Watch

struct LockScreenHuntView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: ActivityTheme { ActivityTheme(colorScheme: colorScheme) }
    let context: ActivityViewContext<HuntActivityAttributes>
    @Environment(\.activityFamily) private var family

    private var progress: HuntProgress { HuntProgress(context: context) }

    var body: some View {
        Group {
            if family == .small {
                watchLayout
            } else {
                phoneLayout
            }
        }
        .foregroundStyle(theme.primaryText)
        .activityBackgroundTint(theme.canvas)
    }

    /// Apple Watch Smart Stack (and CarPlay): small and glanceable.
    private var watchLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressRing(progress: progress, size: 18, lineWidth: 3)
                Text("\(progress.current)/\(progress.total)")
                    .font(.headline)
                    .foregroundStyle(progress.justCleared ? theme.verified : theme.accent)
                Spacer()
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: 60, alignment: .trailing)
            }
            Text(context.state.clue)
                .font(.caption)
                .foregroundStyle(context.state.justCleared ? theme.verified : theme.primaryText)
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
                ElapsedTimer(start: context.attributes.startDate)
                    .font(.headline)
                    .frame(maxWidth: 70, alignment: .trailing)
            }

            if context.state.justCleared {
                Label(context.state.clue, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(theme.verified)
            } else {
                Text(context.state.clue)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Segmented progress bar
            HStack(spacing: 4) {
                ForEach(1...progress.total, id: \.self) { i in
                    Capsule()
                        .fill(progress.isDone(i) ? theme.verified
                              : i == progress.current ? theme.accent
                              : Color.secondary.opacity(0.25))
                        .frame(height: 5)
                }
            }

            Text("Checkpoint \(progress.current) of \(progress.total)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
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
