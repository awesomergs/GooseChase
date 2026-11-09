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
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("\(hunt.checkpoints.count) checkpoints · scan to join")
                            .font(.subheadline.weight(.medium))
                            .opacity(0.9)
                    }

                    if let code = nearby.roomCode {
                        QRCodeView(url: RoomCode.joinURL(code))
                            .frame(maxWidth: 250)
                            .shadow(color: Brand.ink.opacity(0.15), radius: 12, y: 6)

                        VStack(spacing: 4) {
                            Text("or enter code")
                                .font(.subheadline.weight(.medium))
                                .opacity(0.9)
                            Text(code)
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .kerning(8)
                                .textSelection(.enabled)
                                .accessibilityLabel("Room code \(code.map(String.init).joined(separator: " "))")
                        }
                    } else {
                        GooseView(mood: .running)
                            .frame(height: 120)
                            .frame(height: 260)
                    }

                    playersCard
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .foregroundStyle(.white)
            .background(SkyBackground(grassHeight: 120))
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
                .gooseProminent()
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
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
                    .contentTransition(.numericText())
            }
            if nearby.joinedPlayers.isEmpty {
                HStack(spacing: 10) {
                    GooseView(mood: .waiting)
                        .frame(height: 50)
                    Text("Waiting for players… keep this screen open.")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                .padding(.vertical, 2)
            } else {
                ForEach(nearby.joinedPlayers, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Brand.grass)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        .animation(.spring, value: nearby.joinedPlayers)
    }
}
