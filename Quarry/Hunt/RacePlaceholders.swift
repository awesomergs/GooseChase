//
//  RacePlaceholders.swift  ·  OWNER: Person B (temporary)
//  Stub implementations of A's Nearby types so the race flow compiles and demos
//  today while A's real MultipeerConnectivity implementation (Quarry/Nearby/) is
//  still in progress.
//
//  DELETE INSTRUCTIONS:
//    • When Quarry/Nearby/NearbySession.swift lands from A: delete the NearbySession
//      MARK block below (and this whole file once all three sections are deleted).
//    • When Quarry/Nearby/HostLobbyView.swift lands: delete the HostLobbyView block.
//    • When Quarry/Nearby/JoinView.swift lands: delete the JoinView block.
//  None of the call sites need to change — they already target the SPEC §6 signatures.
//

import SwiftUI
import Observation

// MARK: - TEMP NearbySession  (DELETE when Quarry/Nearby/NearbySession.swift lands)

@Observable
@MainActor
final class NearbySession {
    static let shared = NearbySession()

    enum Status: Equatable {
        case idle, hosting, searching, connected
        case failed(String)
    }

    var roomCode: String?
    var isHosting = false
    var connectedPlayers: [String] = []
    var status: Status = .idle
    /// Set by the host when it sends .hunt; observed by JoinView to call onJoined.
    var receivedHunt: HuntPackage?
    /// Set when the host's .start(at:) message arrives; observed by ContentView to begin the race.
    var startAt: Date?

    private init() {
        // Wire race progress back out over the (stub) connection.
        RaceSession.shared.sendHandler = { [weak self] message in
            self?.send(message)
        }
    }

    /// Host: start advertising and return the 4-letter room code.
    @discardableResult
    func startHosting(package: HuntPackage) -> String {
        let code = RoomCode.make()
        roomCode = code
        isHosting = true
        status = .hosting
        return code
    }

    /// Player: begin searching for a host with this room code.
    func join(code rawCode: String) {
        status = .searching
        // Real impl: start MC browser. Stub: nothing happens automatically.
    }

    /// Send a message over the connection (host → all; player → host).
    func send(_ message: NearbyMessage) {
        // Real impl: send over MultipeerConnectivity. Stub: no-op.
    }

    /// Disconnect and reset all state.
    func stop() {
        roomCode = nil
        isHosting = false
        connectedPlayers = []
        status = .idle
        receivedHunt = nil
        startAt = nil
    }
}

// MARK: - TEMP HostLobbyView  (DELETE when Quarry/Nearby/HostLobbyView.swift lands)

struct HostLobbyView: View {
    let hunt: Hunt
    let package: HuntPackage
    let onStart: (Date) -> Void

    @State private var roomCode = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Text("Room Code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(roomCode.isEmpty ? "…" : roomCode)
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundStyle(.indigo)
                        .contentTransition(.identity)
                }
                Text("Players scan a QR code or type this code to join.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                let count = NearbySession.shared.connectedPlayers.count
                Label(count == 0 ? "Waiting for players…"
                                 : "\(count) player\(count == 1 ? "" : "s") joined ✓",
                      systemImage: count == 0 ? "person.2" : "person.2.fill")
                    .foregroundStyle(count == 0 ? Color(.secondaryLabel) : Color.green)
                Spacer()
                Button {
                    onStart(.now + 3)
                } label: {
                    Label("Start for everyone", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
            }
            .padding()
            .navigationTitle(hunt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        NearbySession.shared.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                roomCode = NearbySession.shared.startHosting(package: package)
            }
        }
    }
}

// MARK: - TEMP JoinView  (DELETE when Quarry/Nearby/JoinView.swift lands)

struct JoinView: View {
    let initialCode: String?
    let onJoined: (HuntPackage) -> Void

    @State private var code = ""
    @State private var name = PlayerIdentity.name
    @State private var isWaiting = false
    @Environment(\.dismiss) private var dismiss

    /// A minimal stub package used by the debug "Simulate join" button.
    private static let stubPackage = HuntPackage(
        shareID: UUID(),
        title: "Race (stub)",
        hostName: "Host",
        checkpoints: [
            CheckpointPackage(order: 0, clue: "Find the nearest chair",
                              kindRaw: CheckpointKind.exactMatch.rawValue,
                              referencePrints: [], thumbnail: nil, targetLabel: nil,
                              latitude: nil, longitude: nil,
                              radiusMeters: 40, requiresLocation: false)
        ]
    )

    var body: some View {
        NavigationStack {
            Group {
                if isWaiting {
                    waitingView
                } else {
                    codeEntryForm
                }
            }
            .navigationTitle("Join Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if let c = initialCode { code = c }
        }
        // Real flow: NearbySession receives .hunt, sets receivedHunt, we call onJoined.
        .onChange(of: NearbySession.shared.receivedHunt) { _, hunt in
            guard let hunt, !isWaiting else { return }
            isWaiting = true
            onJoined(hunt)
        }
    }

    // MARK: Code-entry form

    private var codeEntryForm: some View {
        Form {
            Section("Your name") {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, n in PlayerIdentity.name = n }
            }
            Section("Room code") {
                TextField("e.g. ABCD", text: $code)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: code) { _, c in code = String(c.uppercased().prefix(4)) }
            }
            Section {
                Button("Join") {
                    NearbySession.shared.join(code: code)
                }
                .disabled(code.count < 4)
                // Debug-only stub button — simulates receiving the hunt from the host
                Button("Simulate join (debug)") {
                    NearbySession.shared.receivedHunt = Self.stubPackage
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Waiting state

    private var waitingView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
            Text("Waiting for host to start…")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("The race will begin for everyone at the same time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            // Debug-only button — simulates the host tapping "Start for everyone"
            Button("Simulate start (debug)") {
                NearbySession.shared.startAt = .now + 3
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
