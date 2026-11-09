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
        VStack(spacing: 16) {
            GooseView(mood: .celebrate)
                .frame(height: 120)
            Text("Hunt complete!")
                .font(.largeTitle.bold())
            Text(mmss(session.totalTime))
                .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())

            ScrollView {
                splitTimes
                    .skyCard(cornerRadius: 20)

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
                    .padding(.top, 12)
                }
            }
            .scrollIndicators(.hidden)

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .gooseProminent()
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(SkyBackground(grassHeight: 100))
        .fontDesign(.rounded)
    }

    /// A row per checkpoint with the time spent on it.
    private var splitTimes: some View {
        VStack(spacing: 8) {
            ForEach(Array(session.checkpoints.enumerated()), id: \.element.id) { index, _ in
                HStack {
                    Label("Checkpoint \(index + 1)", systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Brand.grass)
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 3))
        } else {
            Image(systemName: "photo")
                .frame(width: 90, height: 90)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
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
