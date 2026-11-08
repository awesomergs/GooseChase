//
//  JoinView.swift  ·  The Join tab: enter a name, type the room code or scan the host's QR,
//  wait in the lobby until the host taps "Start for everyone", then play.
//  Safety net: if the host's connection drops while waiting, "Start now" lets you play anyway
//  (you already have the hunt). Below: "Your games" (joined hunts, best times, replay).
//

import SwiftData
import SwiftUI

struct JoinTab: View {
    /// A code from a quarry://join link (scanned with the iPhone Camera app).
    @Binding var linkCode: String?
    /// Launch the game. Date = synced start time from the host; nil = start now.
    let onStart: (Hunt, Date?) -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Hunt> { $0.isJoined }, sort: \Hunt.createdAt, order: .reverse)
    private var games: [Hunt]

    @State private var code = ""
    @State private var name = PlayerIdentity.name == "Player" ? "" : PlayerIdentity.name
    @State private var showScanner = false
    @State private var autoJoinPaused = false
    /// The hunt we've joined and are waiting to start.
    @State private var lobbyHunt: Hunt?
    @FocusState private var codeFocused: Bool
    private var nearby = NearbySession.shared

    init(linkCode: Binding<String?>, onStart: @escaping (Hunt, Date?) -> Void) {
        _linkCode = linkCode
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            Group {
                if let lobbyHunt {
                    lobby(lobbyHunt)
                } else {
                    entryForm
                }
            }
            .navigationTitle(lobbyHunt == nil ? "Join a Game" : "Lobby")
            .toolbar {
                if lobbyHunt != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Leave") { leaveLobby() }
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { scanned in
                    autoJoinPaused = true
                    code = scanned
                    // Let the scanner finish closing before connecting (more reliable handshake).
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        autoJoinPaused = false
                        startJoin()
                    }
                }
            }
            // The hunt arrived from the host: save it and wait in the lobby (stay connected).
            .onChange(of: nearby.receivedHunt) { _, package in
                guard let package, lobbyHunt == nil else { return }
                let hunt = package.importHunt(into: context)
                hunt.isJoined = true
                try? context.save()
                lobbyHunt = hunt
            }
            // The host tapped "Start for everyone".
            .onChange(of: nearby.startAt) { _, date in
                guard let date, let hunt = lobbyHunt else { return }
                lobbyHunt = nil
                onStart(hunt, date)
            }
            .onChange(of: linkCode) { _, newCode in consumeLinkCode(newCode) }
            .onAppear { consumeLinkCode(linkCode) }
            .sensoryFeedback(.success, trigger: lobbyHunt != nil)
        }
    }

    // MARK: - Entry form

    private var entryForm: some View {
        Form {
            Section {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .onSubmit { codeFocused = true }
            } header: {
                Text("Your name")
            } footer: {
                Text("The host sees this when you join.")
            }

            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan the host's QR code", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                TextField("ABCD", text: $code)
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .kerning(6)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .onChange(of: code) { _, newValue in
                        let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                        if cleaned != newValue { code = cleaned }
                        if cleaned.count == 4, !isBusy, !autoJoinPaused { startJoin() }
                    }
                    .accessibilityLabel("Room code")
            } header: {
                Text("Join")
            } footer: {
                Text("Scan the QR on the host's screen, or type their 4-letter code. Stay close to their phone.")
            }

            if nearby.status != .idle {
                Section { statusRow }
            }

            if !games.isEmpty {
                Section("Your games") {
                    ForEach(games) { hunt in
                        Button {
                            if hunt.isPlayable { onStart(hunt, nil) }
                        } label: {
                            GameRow(hunt: hunt)
                        }
                        .tint(.primary)
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(hunt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch nearby.status {
        case .searching:
            Label { Text("Looking for the host…") } icon: { ProgressView() }
        case .connecting:
            Label { Text("Connecting…") } icon: { ProgressView() }
        case .connected:
            Label { Text("Connected. Getting the hunt…") } icon: { ProgressView() }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Try again") { startJoin() }
                    .disabled(code.count != 4)
            }
        case .disconnected:
            Label("Lost the host. Move closer and try again.", systemImage: "wifi.exclamationmark")
                .foregroundStyle(.orange)
        case .idle, .hosting:
            EmptyView()
        }
    }

    // MARK: - Lobby

    private func lobby(_ hunt: Hunt) -> some View {
        let hostName = nearby.hostName ?? (hunt.hostName.isEmpty ? "the host" : hunt.hostName)
        let connected = nearby.status == .connected
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 6) {
                Text("You're in!")
                    .font(.largeTitle.bold())
                Text(hunt.title)
                    .font(.title3.weight(.semibold))
                Text("\(hunt.checkpoints.count) checkpoints · hosted by \(hostName)")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()

            if connected {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for \(hostName) to start…")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                // Safety net: the connection dropped, but we already have the hunt.
                VStack(spacing: 12) {
                    Label("Lost connection to \(hostName)", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                    Button {
                        lobbyHunt = nil
                        nearby.stop()
                        onStart(hunt, nil)
                    } label: {
                        Label("Start now", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Text("You have the hunt, so you can play without waiting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .animation(.default, value: connected)
    }

    // MARK: - Actions

    private var isBusy: Bool {
        [.searching, .connecting, .connected].contains(nearby.status)
    }

    private func startJoin() {
        guard code.count == 4 else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        PlayerIdentity.name = trimmed.isEmpty ? "Player" : trimmed
        codeFocused = false
        nearby.join(code: code)
    }

    private func leaveLobby() {
        nearby.stop()
        lobbyHunt = nil
        code = ""
    }

    private func consumeLinkCode(_ newCode: String?) {
        guard let newCode, lobbyHunt == nil else { return }
        linkCode = nil
        code = newCode
        startJoin()
    }
}

/// A joined hunt under "Your games": best time and when it was last played.
private struct GameRow: View {
    let hunt: Hunt

    var body: some View {
        HStack(spacing: 12) {
            huntThumbnail(hunt.orderedCheckpoints.first?.thumbnail)
            VStack(alignment: .leading, spacing: 2) {
                Text(hunt.title)
                    .font(.headline)
                if let best = hunt.bestTime, let played = hunt.lastPlayedAt {
                    Text("Best \(mmss(best)) · \(played.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not played yet · from \(hunt.hostName.isEmpty ? "a friend" : hunt.hostName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    JoinTab(linkCode: .constant(nil)) { _, _ in }
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
