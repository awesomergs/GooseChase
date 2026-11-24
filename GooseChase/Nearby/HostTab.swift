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
                HuntTabHeader(title: "Bring the flock", subtitle: "Pick a hunt. Get everyone together.")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                if playable.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(hunts.isEmpty ? "Your first chase starts here" : "Almost ready to host")
                            .font(.title2.bold())
                        Text("Create a hunt with a clue and reference photos for every checkpoint, then invite your friends.")
                            .foregroundStyle(.secondary)
                        Button("Create a hunt", systemImage: "plus", action: onCreateHunt)
                            .gooseProminent()
                            .foregroundStyle(Brand.ink)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    Text("Ready to host")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .listRowBackground(Color.clear)
                    ForEach(playable) { hunt in
                        VStack(alignment: .leading, spacing: 14) {
                            HuntRow(hunt: hunt)
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.46, blue: 0.23))
                            Button {
                                lobbyHunt = hunt
                            } label: {
                                Text("Host this hunt")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                            }
                            .gooseProminent()
                            .foregroundStyle(Brand.ink)
                        }
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                        .padding(.horizontal, 16)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if !unfinished.isEmpty {
                    Text("Needs a little work")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .listRowBackground(Color.clear)
                    ForEach(unfinished) { hunt in
                        Button(action: onCreateHunt) {
                            HStack {
                                HuntRow(hunt: hunt)
                                Spacer(minLength: 8)
                                Image(systemName: "pencil")
                                    .accessibilityHidden(true)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens your hunts in the Create tab.")
                        .padding(.horizontal, 16)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(12)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(HuntTabBackground())
            .toolbar(.hidden, for: .navigationBar)
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

#Preview {
    HostTab(onStart: { _, _ in }, onCreateHunt: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
