//
//  PlayView.swift  ·  OWNER: Person B (hunt flow)
//  The play experience: clue screen → camera → cleared screen → next clue → finished.
//  Extracted from ContentView. Keeps the quarry://camera deep link.
//

import SwiftUI
import SwiftData

// Lets ContentView present a HuntSession with .fullScreenCover(item:).
extension HuntSession: Identifiable {}

struct PlayView: View {
    @Bindable var session: HuntSession
    let onClose: () -> Void
    @State private var showCamera = false

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
        .fullScreenCover(isPresented: $showCamera) {
            if let cp = session.current {
                VerifyCameraView(checkpoint: cp) {
                    showCamera = false
                    session.clearCurrent()
                }
            }
        }
        // Tapping the Live Activity / Dynamic Island opens quarry://camera.
        .onOpenURL { url in
            if url.host == "camera", session.current != nil { showCamera = true }
        }
    }

    // MARK: Clue screen

    private var playScreen: some View {
        VStack(spacing: 20) {
            topBar
            progressBar
            Text("Checkpoint \(session.progressText)")
                .font(.headline)
                .foregroundStyle(.secondary)
            clueCard
            Spacer()
            Button {
                showCamera = true
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

// MARK: - Cleared

private struct CheckpointClearedView: View {
    @Bindable var session: HuntSession

    private var isLast: Bool { session.lastClearedNumber == session.checkpoints.count }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
            Text("Checkpoint \(session.lastClearedNumber) cleared!")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Label(mmss(session.lastSplit ?? 0), systemImage: "stopwatch")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                session.advance()
            } label: {
                Text(isLast ? "Finish" : "Next clue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }
}

// MARK: - Finished

private struct HuntFinishedView: View {
    let session: HuntSession
    let onDone: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 56))
            Text("Hunt complete!")
                .font(.largeTitle.bold())
            Label(mmss(session.totalTime), systemImage: "stopwatch")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(session.checkpoints) { cp in
                        thumbnail(for: cp.thumbnail)
                    }
                }
                .padding(.top, 8)
            }
            Button {
                onDone()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    @ViewBuilder
    private func thumbnail(for data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(width: 90, height: 90)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Helpers

/// Formats a duration as m:ss.
private func mmss(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
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
