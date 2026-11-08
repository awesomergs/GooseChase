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
        VStack(spacing: 20) {
            topBar
            progressBar
            rankPill
            Text("Checkpoint \(session.progressText)")
                .font(.headline)
                .foregroundStyle(.secondary)
            clueCard
            Spacer()
            Button {
                cameraCheckpoint = session.current
            } label: {
                Label("Open camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
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

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(session.checkpoints.indices, id: \.self) { i in
                Capsule()
                    .fill(segmentColor(for: i))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Rank pill shown below the progress bar during a race.
    @ViewBuilder
    private var rankPill: some View {
        if RaceSession.shared.isActive, let rank = RaceSession.shared.myRank {
            Text("You're \(ordinal(rank))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.indigo, in: Capsule())
                .animation(.spring(duration: 0.3), value: rank)
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if index < session.currentIndex {
            .indigo                       // cleared
        } else if index == session.currentIndex {
            .indigo.opacity(0.45)         // current
        } else {
            Color.secondary.opacity(0.25) // upcoming
        }
    }

    private var clueCard: some View {
        Text(session.current?.clue ?? "")
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Race countdown overlay

private struct RaceCountdownView: View {
    let count: Int

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("\(count)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.indigo)
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
