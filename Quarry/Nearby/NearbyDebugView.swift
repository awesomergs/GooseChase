//
//  NearbyDebugView.swift  ·  OWNER: Person C · DEBUG ONLY, delete before the demo
//  A bare test screen for NearbySession on two phones, before the real Host/Join screens exist.
//  Open it with the small antenna button in the bottom-left corner (DEBUG builds only).
//

#if DEBUG
import SwiftData
import SwiftUI

struct NearbyDebugView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    @Query(sort: \Hunt.createdAt) private var hunts: [Hunt]
    @State private var code = ""
    @State private var name = PlayerIdentity.name
    private var nearby = NearbySession.shared
    private var race = RaceSession.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("This phone") {
                    TextField("Your name", text: $name)
                        .onSubmit { PlayerIdentity.name = name }
                    LabeledContent("Status", value: String(describing: nearby.status))
                    if let roomCode = nearby.roomCode {
                        LabeledContent("Room code", value: roomCode)
                    }
                }
                .listRowBackground(theme.card)

                Section("Host") {
                    ForEach(hunts) { hunt in
                        Button("Host \"\(hunt.title)\" (\(hunt.checkpoints.count))") {
                            PlayerIdentity.name = name
                            RaceSession.shared.end()
                            nearby.startHosting(package: Self.debugPackage(for: hunt))
                        }
                    }
                    if nearby.isHosting {
                        LabeledContent("Players", value: nearby.connectedPlayers.joined(separator: ", "))
                        Button("Start race in 3 s") {
                            let date = Date.now.addingTimeInterval(3)
                            nearby.startRace(at: date)
                            if let roomHunt = hunts.first {
                                race.begin(huntShareID: roomHunt.shareID, total: roomHunt.checkpoints.count,
                                           isHost: true, startAt: date)
                            }
                        }
                    }
                }
                .listRowBackground(theme.card)

                Section("Join") {
                    TextField("4-letter code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Join") {
                        PlayerIdentity.name = name
                        nearby.join(code: code)
                    }
                    .disabled(code.count != 4)
                    if let hunt = nearby.receivedHunt {
                        LabeledContent("Received", value: "\(hunt.title) · \(hunt.checkpoints.count) checkpoints")
                    }
                    if let start = nearby.startAt {
                        LabeledContent("Start at", value: start.formatted(date: .omitted, time: .standard))
                        Button("Begin race on this phone") {
                            if let hunt = nearby.receivedHunt {
                                race.begin(huntShareID: hunt.shareID, total: hunt.checkpoints.count,
                                           isHost: false, startAt: start)
                            }
                        }
                    }
                }
                .listRowBackground(theme.card)

                Section("Race") {
                    Button("Report +1 cleared") {
                        let total = race.me?.total ?? 3
                        race.reportProgress(cleared: (race.me?.cleared ?? 0) + 1, total: total)
                    }
                    .disabled(!race.isActive)
                    NavigationLink("Leaderboard") { LeaderboardView() }
                }
                .listRowBackground(theme.card)

                Section {
                    Button("Stop everything", role: .destructive) {
                        nearby.stop()
                        race.end()
                    }
                }
                .listRowBackground(theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .foregroundStyle(theme.primaryText)
            .tint(theme.accent)
            .navigationTitle("Nearby test")
        }
    }

    /// Minimal conversion for testing; B's HuntPackage(hunt:) replaces this.
    static func debugPackage(for hunt: Hunt) -> HuntPackage {
        HuntPackage(
            shareID: hunt.shareID,
            title: hunt.title,
            hostName: PlayerIdentity.name,
            checkpoints: hunt.orderedCheckpoints.map { cp in
                CheckpointPackage(
                    order: cp.order, clue: cp.clue, kindRaw: cp.kindRaw,
                    referencePrints: cp.referencePrints, thumbnail: cp.thumbnail,
                    targetLabel: cp.targetLabel, latitude: cp.latitude, longitude: cp.longitude,
                    radiusMeters: cp.radiusMeters, requiresLocation: cp.requiresLocation
                )
            }
        )
    }
}

/// Small floating button that opens the debug screen. Added in QuarryApp (DEBUG only).
struct NearbyDebugButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showing = false
    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .padding(10)
        }
        .buttonStyle(.glass)
        .tint(QuarryTheme(colorScheme: colorScheme).accent)
        .accessibilityLabel("Nearby test")
        .padding()
        .sheet(isPresented: $showing) { NearbyDebugView() }
    }
}
#endif
