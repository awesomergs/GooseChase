//
//  HuntFinishedView.swift  ·  OWNER: Person B (hunt flow)
//  The finish screen: total time, per-checkpoint split times, and either the live
//  leaderboard (when racing) or a thumbnail grid of the cleared checkpoints.
//  Presented by PlayView when session.isFinished.
//

import SwiftUI

struct HuntFinishedView: View {
    let session: HuntSession
    let onDone: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        VStack(spacing: 20) {
            Image("d f")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            Text("Hunt complete!")
                .font(.largeTitle.bold())
            Label(mmss(session.totalTime), systemImage: "stopwatch")
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)

            ScrollView {
                splitTimes
                    .padding(.top, 8)

                if RaceSession.shared.isActive {
                    LeaderboardView()
                        .frame(minHeight: 240)
                        .padding(.top, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(session.checkpoints) { cp in
                            thumbnail(for: cp.thumbnail)
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Button {
                onDone()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    /// A row per checkpoint with the time spent on it.
    private var splitTimes: some View {
        VStack(spacing: 8) {
            ForEach(Array(session.checkpoints.enumerated()), id: \.element.id) { index, _ in
                HStack {
                    Text("Checkpoint \(index + 1)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if session.splits.indices.contains(index) {
                        Text(mmss(session.splits[index]))
                            .monospacedDigit()
                    }
                }
                .font(.subheadline)
            }
        }
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

#Preview {
    let hunt = Hunt(title: "Birthday Hunt")
    hunt.checkpoints = [
        Checkpoint(order: 0, clue: "Find the red balloon by the door", kind: .exactMatch),
        Checkpoint(order: 1, clue: "Look where the cake is hiding", kind: .exactMatch),
    ]
    let session = HuntSession(hunt: hunt)
    session.start()
    session.clearCurrent()
    session.advance()
    session.clearCurrent()
    session.advance()
    return HuntFinishedView(session: session) {}
}
