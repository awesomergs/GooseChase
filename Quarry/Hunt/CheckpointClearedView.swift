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
        VStack(spacing: 18) {
            Spacer()
            GooseView(mood: .honk)
                .frame(height: 130)
            Text("Honk! Checkpoint \(session.lastClearedNumber) cleared")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // The checkpoint just cleared is still session.current (advance hasn't run).
            thumbnail(for: session.current?.thumbnail)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Brand.grass)
                        .offset(x: 10, y: 10)
                }

            Label(mmss(session.lastSplit ?? 0), systemImage: "stopwatch")
                .font(.title3.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())

            rankLine
            Spacer()
            Button {
                session.advance()
            } label: {
                Text(isLast ? "Finish" : "Next clue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .gooseProminent()
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(SkyBackground(grassHeight: 110))
    }

    /// "You're Nth" during a race.
    @ViewBuilder
    private var rankLine: some View {
        if RaceSession.shared.isActive, let rank = RaceSession.shared.myRank {
            Text("You're \(ordinal(rank))")
                .font(.headline)
                .foregroundStyle(.white)
                .animation(.spring(duration: 0.3), value: rank)
        }
    }

    @ViewBuilder
    private func thumbnail(for data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 4))
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .frame(width: 130, height: 130)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
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
