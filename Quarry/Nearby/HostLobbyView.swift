//
//  HostLobbyView.swift  ·  The host's lobby: big QR + room code, who has joined,
//  and "Start for everyone" (sends a synced start time; everyone counts down 3-2-1).
//

import SwiftUI

struct HostLobbyView: View {
    let hunt: Hunt
    /// Called with the synced start time; the caller launches the game on this phone too.
    let onStart: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    private var nearby = NearbySession.shared

    init(hunt: Hunt, onStart: @escaping (Date) -> Void) {
        self.hunt = hunt
        self.onStart = onStart
    }

    private var playerCount: Int { nearby.joinedPlayers.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text(hunt.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("\(hunt.checkpoints.count) checkpoints · scan to join")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let code = nearby.roomCode {
                        QRCodeView(url: RoomCode.joinURL(code))
                            .frame(maxWidth: 260)

                        VStack(spacing: 4) {
                            Text("or enter code")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(code)
                                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                                .kerning(8)
                                .textSelection(.enabled)
                                .accessibilityLabel("Room code \(code.map(String.init).joined(separator: " "))")
                        }
                    } else {
                        ProgressView("Starting…")
                            .frame(height: 260)
                    }

                    playersCard
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                Button {
                    let date = Date.now.addingTimeInterval(4)
                    if playerCount > 0 { nearby.startRace(at: date) }
                    onStart(date)
                } label: {
                    Label(playerCount == 0 ? "Start solo" : "Start for everyone (\(playerCount + 1))",
                          systemImage: "flag.checkered")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        nearby.stop()
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.success, trigger: playerCount)
            .onAppear {
                if !nearby.isHosting {
                    var package = HuntPackage(hunt: hunt)
                    if package.hostName.isEmpty { package.hostName = PlayerIdentity.name }
                    nearby.startHosting(package: package)
                }
            }
        }
    }

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Players")
                    .font(.headline)
                Spacer()
                Text("\(playerCount)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if nearby.joinedPlayers.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for players… keep this screen open.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(nearby.joinedPlayers, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring, value: nearby.joinedPlayers)
    }
}
