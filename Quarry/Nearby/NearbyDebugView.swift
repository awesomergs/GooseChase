//
//  NearbyDebugView.swift  ·  OWNER: Person C · DEBUG ONLY, delete before the demo
//  A bare test screen for NearbySession on two phones, before the real Host/Join screens exist.
//  Open it with the small antenna button in the bottom-left corner (DEBUG builds only).
//

#if DEBUG
import SwiftData
import SwiftUI

struct NearbyDebugView: View {
    @Query(sort: \Hunt.createdAt) private var hunts: [Hunt]
    @State private var code = ""
    @State private var name = PlayerIdentity.name
    @State private var lobbyHunt: Hunt?
    @State private var showJoin = false
    private var nearby = NearbySession.shared
    private var race = RaceSession.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("This phone") {
                    LabeledContent("Build", value: Self.buildStamp)
                    TextField("Your name", text: $name)
                        .onSubmit { PlayerIdentity.name = name }
                    LabeledContent("Status") {
                        Text(String(describing: nearby.status)).multilineTextAlignment(.trailing)
                    }
                    if let roomCode = nearby.roomCode {
                        LabeledContent("Room code", value: roomCode)
                    }
                }

                Section("Real screens (N3)") {
                    ForEach(hunts) { hunt in
                        Button("Open Host lobby for \"\(hunt.title)\"") { lobbyHunt = hunt }
                    }
                    Button("Open Join screen") { showJoin = true }
                }

                Section("Host (raw test)") {
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

                Section("Race") {
                    Button("Report +1 cleared") {
                        let total = race.me?.total ?? 3
                        race.reportProgress(cleared: (race.me?.cleared ?? 0) + 1, total: total)
                    }
                    .disabled(!race.isActive)
                    NavigationLink("Leaderboard") { LeaderboardView() }
                }

                Section("Log (newest first)") {
                    if nearby.log.isEmpty {
                        Text("Nothing yet").foregroundStyle(.secondary)
                    }
                    ForEach(Array(nearby.log.reversed().enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button("Stop everything", role: .destructive) {
                        nearby.stop()
                        race.end()
                    }
                }
            }
            .navigationTitle("Nearby test")
            .sheet(item: $lobbyHunt) { hunt in HostLobbyView(hunt: hunt) }
            .sheet(isPresented: $showJoin) { JoinView() }
        }
    }

    /// When this copy of the app was built. Both phones should show the same time.
    static let buildStamp: String = {
        guard let path = Bundle.main.executablePath,
              let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        else { return "unknown" }
        return date.formatted(date: .omitted, time: .standard)
    }()

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
    @State private var showing = false
    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .padding(10)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Nearby test")
        .padding()
        .sheet(isPresented: $showing) { NearbyDebugView() }
    }
}
#endif
