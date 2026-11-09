//
//  HostTab.swift  ·  Host tab: pick one of your hunts → lobby (QR + code) → Start for everyone.
//

import SwiftUI
import SwiftData

struct HostTab: View {
    /// Launch the game on this phone. Date = synced start time.
    let onStart: (Hunt, Date?) -> Void
    let onCreateHunt: () -> Void

    @Query(filter: #Predicate<Hunt> { !$0.isJoined }, sort: \Hunt.createdAt, order: .reverse)
    private var hunts: [Hunt]
    @State private var lobbyHunt: Hunt?

    private var playable: [Hunt] { hunts.filter(\.isPlayable) }
    private var unfinished: [Hunt] { hunts.filter { !$0.isPlayable } }

    var body: some View {
        NavigationStack {
            List {
                if !playable.isEmpty {
                    Section {
                        ForEach(playable) { hunt in
                            Button {
                                lobbyHunt = hunt
                            } label: {
                                HStack {
                                    HuntRow(hunt: hunt)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .tint(.primary)
                        }
                    } header: {
                        Text("Pick a hunt to host")
                    } footer: {
                        Text("Friends join from the Join tab by scanning your QR code. Everyone starts together.")
                    }
                }

                if !unfinished.isEmpty {
                    Section("Not ready yet") {
                        ForEach(unfinished) { hunt in
                            HuntRow(hunt: hunt)
                                .opacity(0.6)
                        }
                    }
                }
            }
            .overlay {
                if playable.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 8) {
                            GooseView(mood: .waiting)
                                .frame(height: 110)
                            Text("Nothing to host yet")
                        }
                    } description: {
                        Text("Create a hunt with photos for each checkpoint, then host it here.")
                    } actions: {
                        Button("Create a hunt", action: onCreateHunt)
                            .gooseProminent()
                    }
                }
            }
            .pageBackground()
            .navigationTitle("Host a Game")
            .sheet(item: $lobbyHunt) { hunt in
                HostLobbyView(hunt: hunt) { date in
                    lobbyHunt = nil
                    // Let the lobby sheet finish closing before the game covers the screen.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        onStart(hunt, date)
                    }
                }
                .interactiveDismissDisabled()
            }
        }
    }
}
