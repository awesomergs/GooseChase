//
//  LeaderboardView.swift  ·  OWNER: Person C (Rohan)
//  Live race standings. Reads RaceSession.shared by default; updates automatically.
//  B shows it in a sheet during play and on the finish screen.
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.primaryText)
        .tint(theme.accent)
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: race.players.map(\.id))
        .sensoryFeedback(.selection, trigger: race.myRank)
        .navigationTitle("Leaderboard")
    }
}

struct LeaderboardRow: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    let rank: Int
    let player: PlayerProgress
    let isMe: Bool
    let finishTime: TimeInterval?

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: rank)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isMe ? "You" : player.name)
                        .font(.body.weight(isMe ? .bold : .regular))
                    statusText
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(player.finishedAt != nil ? theme.verified : theme.secondaryText)
                }
                ProgressSegments(cleared: player.cleared, total: player.total,
                                 finished: player.finishedAt != nil)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isMe ? theme.sand : theme.card)
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
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(rank == 1 ? theme.onAccent : theme.primaryText)
            .frame(width: 32, height: 32)
            .background(rank == 1 ? theme.accent : theme.sand, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct ProgressSegments: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    let cleared: Int
    let total: Int
    let finished: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < cleared ? theme.verified
                                      : theme.secondaryText.opacity(0.2))
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
