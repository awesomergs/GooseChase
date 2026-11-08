//
//  HostLobbyView.swift  ·  OWNER: Person C
//  The host shows this: a big QR + room code, and a live list of who has joined.
//  Present it as a sheet: HostLobbyView(hunt: hunt)
//

import SwiftUI

struct HostLobbyView: View {
    let hunt: Hunt
    /// Optional: the host taps "Play now" to start their own copy of the hunt.
    var onPlay: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private var nearby = NearbySession.shared

    init(hunt: Hunt, onPlay: (() -> Void)? = nil) {
        self.hunt = hunt
        self.onPlay = onPlay
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Scan to join")
                            .font(.title2.bold())
                        Text(hunt.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let code = nearby.roomCode {
                        QRCodeView(url: RoomCode.joinURL(code))
                            .frame(maxWidth: 280)

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
                            .frame(height: 280)
                    }

                    playersSection

                    Text("Keep this screen open until everyone has joined. Players need to be close to this phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        nearby.stop()
                        dismiss()
                    }
                }
                if let onPlay {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Play now") {
                            nearby.stop()
                            dismiss()
                            onPlay()
                        }
                    }
                }
            }
            .sensoryFeedback(.success, trigger: nearby.joinedPlayers.count)
            .onAppear {
                if !nearby.isHosting {
                    nearby.startHosting(package: HuntTransfer.package(for: hunt))
                }
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Joined")
                    .font(.headline)
                Spacer()
                Text("\(nearby.joinedPlayers.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if nearby.joinedPlayers.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for players…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(nearby.joinedPlayers, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
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
