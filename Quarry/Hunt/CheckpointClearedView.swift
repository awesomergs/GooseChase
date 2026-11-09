//
//  CheckpointClearedView.swift  ·  OWNER: Person B (hunt flow)
//  The "Checkpoint N cleared!" screen shown between clearing a checkpoint and advancing.
//  Presented by PlayView while session.isAwaitingAdvance; HuntSession arms a 3-second
//  auto-advance so this screen moves on by itself, or sooner via the button.
//

import SwiftUI

struct CheckpointClearedView: View {
    @Bindable var session: HuntSession

    private var isLast: Bool { session.lastClearedNumber == session.checkpoints.count }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(QuarryTheme(colorScheme: .light).verified)
            Text("Checkpoint \(session.lastClearedNumber) cleared!")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // The checkpoint just cleared is still session.current (advance hasn't run).
            thumbnail(for: session.current?.thumbnail)

            Label(mmss(session.lastSplit ?? 0), systemImage: "stopwatch")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)

            rankLine
            Spacer()
            Button {
                session.advance()
            } label: {
                Text(isLast ? "Finish" : "Next clue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    /// "You're Nth" during a race.
    @ViewBuilder
    private var rankLine: some View {
        if RaceSession.shared.isActive, let rank = RaceSession.shared.myRank {
            Text("You're \(ordinal(rank))")
                .font(.headline)
                .foregroundStyle(QuarryTheme(colorScheme: .light).accent)
                .animation(.spring(duration: 0.3), value: rank)
        }
    }

    @ViewBuilder
    private func thumbnail(for data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    let hunt = Hunt(title: "Birthday Hunt")
    hunt.checkpoints = [
        Checkpoint(order: 0, clue: "Find the red balloon by the door", kind: .exactMatch),
        Checkpoint(order: 1, clue: "Look where the cake is hiding", kind: .exactMatch),
    ]
    let session = HuntSession(hunt: hunt)
    session.start()
    session.clearCurrent()
    return CheckpointClearedView(session: session)
}
