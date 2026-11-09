//
//  PlayView.swift  ·  OWNER: Person B (hunt flow)
//  The play experience: clue screen → camera → cleared screen → next clue → finished.
//  Extracted from ContentView. Keeps the quarry://camera deep link.
//
//  Race additions:
//    • startAt: Date? — when non-nil, shows a 3-2-1 countdown overlay and calls
//      session.start() only when the clock reaches that date (for synced race starts).
//      Nil = solo; caller already called session.start() before presenting this view.
//    • list.number leaderboard button in the top bar (shown when a race is active).
//    • "You're Nth" rank pill under the progress bar (shown when racing).
//
//  The cleared and finished screens live in CheckpointClearedView.swift and
//  HuntFinishedView.swift; they reuse the module-level mmss / ordinal helpers below.
//

import SwiftUI
import SwiftData

// Lets ContentView present a HuntSession with .fullScreenCover(item:).
extension HuntSession: Identifiable {}

struct PlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    @Bindable var session: HuntSession
    /// Synced start time for a race. Nil for solo play (session.start() was already
    /// called by the presenter). When non-nil, a 3-2-1 countdown is shown and
    /// session.start() is called at this time.
    var startAt: Date? = nil
    let onClose: () -> Void

    @State private var cameraCheckpoint: Checkpoint?
    @State private var showLeaderboard = false
    /// Current countdown number (3, 2, 1). Nil when not counting down.
    @State private var countdown: Int? = nil

    var body: some View {
        Group {
            if session.isFinished {
                HuntFinishedView(session: session, onDone: onClose)
            } else if session.isAwaitingAdvance {
                CheckpointClearedView(session: session)
            } else {
                playScreen
            }
        }
        .background(theme.canvas)
        .tint(theme.accent)
        .sensoryFeedback(.success, trigger: session.lastClearedNumber)
        .fullScreenCover(item: $cameraCheckpoint) { cp in
            VerifyCameraView(checkpoint: cp) {
                // Close the camera instantly (no slide-away animation) so the
                // "Next clue" button on the cleared screen responds right away.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { cameraCheckpoint = nil }
                session.clearCurrent()
            }
        }
        // Tapping the Live Activity / Dynamic Island opens quarry://camera.
        .onOpenURL { url in
            if url.host == "camera" { cameraCheckpoint = session.current }
        }
        .sheet(isPresented: $showLeaderboard) {
            NavigationStack { LeaderboardView() }
        }
        // 3-2-1 countdown overlay for synced race starts.
        .overlay {
            if let n = countdown {
                RaceCountdownView(count: n)
            }
        }
        .task { await runCountdown() }
    }

    // MARK: Countdown

    /// Runs the 3-2-1 countdown when startAt is set, then calls session.start().
    /// For solo play (startAt == nil) this exits immediately — the caller already started.
    private func runCountdown() async {
        guard let startAt else { return }

        // If the start time has already passed (e.g. slight delay presenting the view),
        // just start immediately.
        guard startAt > .now else {
            session.start()
            return
        }

        // Tick down each second, showing the ceiling integer distance.
        var secondsLeft = max(1, Int(startAt.timeIntervalSinceNow.rounded(.up)))
        countdown = secondsLeft
        while secondsLeft > 1 {
            try? await Task.sleep(for: .seconds(1))
            secondsLeft -= 1
            countdown = secondsLeft
        }

        // Sleep any residual sub-second time before the exact start.
        let residual = startAt.timeIntervalSinceNow
        if residual > 0 {
            try? await Task.sleep(for: .seconds(residual))
        }

        countdown = nil
        session.start()
    }

    // MARK: Clue screen

    private var playScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QuarryTheme.sectionSpacing) {
                topBar
                rankPill
                QuarryProgressView(cleared: min(session.currentIndex, session.checkpoints.count),
                                   total: session.checkpoints.count)
                if let cp = session.current {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Checkpoint \(session.progressText)", systemImage: "mappin.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Text(cp.clue)
                            .font(.system(.title, design: .rounded).bold())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(theme.card, in: .rect(cornerRadius: QuarryTheme.cardRadius))
                    metrics
                    Label("Point your camera at the object when you find it.", systemImage: "camera")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.sand, in: .rect(cornerRadius: QuarryTheme.cardRadius))
                }
                if inlineAction {
                    primaryAction
                }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if !inlineAction {
                primaryAction
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(theme.canvas)
            }
        }
        .foregroundStyle(theme.primaryText)
        .background(theme.canvas)
    }

    private var inlineAction: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    private var primaryAction: some View {
        QuarryPrimaryButton(title: "Open camera", systemImage: "camera.fill") {
            cameraCheckpoint = session.current
        }
    }

    private var metrics: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            QuarryMetricView(title: "Cleared",
                             value: Text("\(min(session.currentIndex, session.checkpoints.count)) of \(session.checkpoints.count)"),
                             systemImage: "flag.checkered")
            QuarryMetricView(title: "Elapsed",
                             value: Text(timerInterval: session.startDate...Date.distantFuture,
                                         countsDown: false),
                             systemImage: "clock")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                session.quit()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
            }
            .accessibilityLabel("End hunt")

            Spacer()

            Text(session.startDate, style: .timer)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)

            if RaceSession.shared.isActive {
                Button {
                    showLeaderboard = true
                } label: {
                    Image(systemName: "list.number")
                        .font(.headline)
                }
                .padding(.leading, 12)
                .accessibilityLabel("Leaderboard")
            }
        }
    }

    /// Rank pill shown below the progress bar during a race.
    @ViewBuilder
    private var rankPill: some View {
        if RaceSession.shared.isActive, let rank = RaceSession.shared.myRank {
            Text("You're \(ordinal(rank))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.accent, in: Capsule())
                .animation(.spring(duration: 0.3), value: rank)
        }
    }
}

// MARK: - Race countdown overlay

private struct RaceCountdownView: View {
    let count: Int

    var body: some View {
        ZStack {
            QuarryTheme(colorScheme: .light).canvas
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("\(count)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(QuarryTheme(colorScheme: .light).accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(duration: 0.35), value: count)
                Text("Get ready!")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Helpers
// Shared by PlayView, CheckpointClearedView and HuntFinishedView.

/// Formats a duration as m:ss.
func mmss(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// Returns "1st", "2nd", "3rd", "4th", etc.
func ordinal(_ n: Int) -> String {
    let suffix: String
    if (11...13).contains(n % 100) {
        suffix = "th"
    } else {
        switch n % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(n)\(suffix)"
}

#Preview {
    let hunt = Hunt(title: "Birthday Hunt")
    hunt.checkpoints = [
        Checkpoint(order: 0, clue: "Find the red balloon by the door", kind: .exactMatch),
        Checkpoint(order: 1, clue: "Look where the cake is hiding", kind: .exactMatch),
        Checkpoint(order: 2, clue: "The last gift is under the table", kind: .exactMatch),
    ]
    return PlayView(session: HuntSession(hunt: hunt)) {}
}
