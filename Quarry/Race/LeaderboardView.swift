//
//  LeaderboardView.swift  ·  OWNER: Person C (Rohan)
//  Live race standings. Reads RaceSession.shared by default; updates automatically.
//  B shows it in a sheet during play and on the finish screen.
//

import SwiftUI

struct LeaderboardView: View {
    var race: RaceSession = .shared

    var body: some View {
        List {
            if race.players.isEmpty {
                ContentUnavailableView(
                    "No racers yet",
                    systemImage: "flag.2.crossed",
                    description: Text("Players show up here as soon as they join.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(Array(race.players.enumerated()), id: \.element.id) { index, player in
                        LeaderboardRow(
                            rank: index + 1,
                            player: player,
                            isMe: player.id == race.myID,
                            finishTime: race.finishTime(of: player)
                        )
                    }
                } footer: {
                    Text(race.isHost ? "You're hosting. Standings update as players clear checkpoints."
                                     : "Standings update live from the host's phone.")
                }
            }
        }
        .animation(.spring(duration: 0.4), value: race.players.map(\.id))
        .sensoryFeedback(.selection, trigger: race.myRank)
        .navigationTitle("Leaderboard")
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let player: PlayerProgress
    let isMe: Bool
    let finishTime: TimeInterval?

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: rank)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isMe ? "You" : player.name)
                        .font(.body.weight(isMe ? .bold : .regular))
                    Spacer()
                    statusText
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(player.finishedAt != nil ? Color.green : Color.secondary)
                }
                ProgressSegments(cleared: player.cleared, total: player.total,
                                 finished: player.finishedAt != nil)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isMe ? Color.indigo.opacity(0.08) : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var statusText: some View {
        if player.finishedAt != nil {
            if let finishTime {
                Label(Self.format(finishTime), systemImage: "checkmark.circle.fill")
            } else {
                Label("Finished", systemImage: "checkmark.circle.fill")
            }
        } else {
            Text("\(player.cleared) of \(player.total)")
        }
    }

    private var accessibilityText: String {
        let who = isMe ? "You" : player.name
        if player.finishedAt != nil { return "\(rank). \(who), finished" }
        return "\(rank). \(who), \(player.cleared) of \(player.total) checkpoints"
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct RankBadge: View {
    let rank: Int

    private var tint: Color {
        switch rank {
        case 1: .yellow
        case 2: .gray
        case 3: .brown
        default: .secondary
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(rank <= 3 ? Color.white : Color.secondary)
            .frame(width: 32, height: 32)
            .background(rank <= 3 ? tint : Color.secondary.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct ProgressSegments: View {
    let cleared: Int
    let total: Int
    let finished: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < cleared ? (finished ? Color.green : Color.indigo)
                                      : Color.secondary.opacity(0.2))
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Racing") {
    NavigationStack {
        LeaderboardView(race: .preview())
    }
}

#Preview("Empty") {
    NavigationStack {
        LeaderboardView(race: RaceSession())
    }
}
