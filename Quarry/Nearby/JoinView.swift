//
//  JoinView.swift  ·  OWNER: Person C
//  A player types the room code or scans the host's QR; the hunt arrives
//  phone-to-phone and is saved into this phone's hunt list.
//  Present as a sheet: JoinView(initialCode: code, onPlay: { hunt in … })
//

import SwiftData
import SwiftUI

struct JoinView: View {
    var initialCode: String? = nil
    /// Called when the player taps "Play now" after joining. If nil, the button just closes.
    var onPlay: ((Hunt) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = PlayerIdentity.name == "Player" ? "" : PlayerIdentity.name
    @State private var showScanner = false
    @State private var joinedHunt: Hunt?
    @State private var autoJoinPaused = false
    @FocusState private var codeFocused: Bool
    private var nearby = NearbySession.shared

    init(initialCode: String? = nil, onPlay: ((Hunt) -> Void)? = nil) {
        self.initialCode = initialCode
        self.onPlay = onPlay
    }

    var body: some View {
        NavigationStack {
            Group {
                if let joinedHunt {
                    joinedView(joinedHunt)
                } else {
                    form
                }
            }
            .navigationTitle("Join a hunt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(joinedHunt == nil ? "Cancel" : "Done") {
                        nearby.stop()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { scanned in
                    autoJoinPaused = true
                    code = scanned
                    // Let the scanner finish closing and release the camera before connecting;
                    // starting the connection mid-dismiss made the first handshake fail.
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        autoJoinPaused = false
                        startJoin()
                    }
                }
            }
            .onChange(of: nearby.receivedHunt) { _, package in
                guard let package, joinedHunt == nil else { return }
                joinedHunt = HuntTransfer.save(package, into: context)
                nearby.stop()   // got the hunt; no need to stay connected
            }
            .sensoryFeedback(.success, trigger: joinedHunt != nil)
            .onAppear {
                if let initialCode, !initialCode.isEmpty {
                    code = initialCode.uppercased()
                    startJoin()
                }
            }
        }
    }

    // MARK: - Form

    private var form: some View {
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

                Button {
                    showScanner = true
                } label: {
                    Label("Scan QR code", systemImage: "qrcode.viewfinder")
                }
            } header: {
                Text("Room code")
            } footer: {
                Text("Ask the host for the 4-letter code, or scan the QR on their screen. Stay close to their phone.")
            }

            Section {
                statusRow
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
            Label { Text("Connected. Downloading the hunt…") } icon: { ProgressView() }
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
            Button("Join") { startJoin() }
                .disabled(code.count != 4)
        }
    }

    private var isBusy: Bool {
        [.searching, .connecting, .connected].contains(nearby.status)
    }

    private func startJoin() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        PlayerIdentity.name = trimmed.isEmpty ? "Player" : trimmed
        codeFocused = false
        nearby.join(code: code)
    }

    // MARK: - Joined

    private func joinedView(_ hunt: Hunt) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: true)
            VStack(spacing: 6) {
                Text("You're in!")
                    .font(.largeTitle.bold())
                Text(hunt.title)
                    .font(.title3.weight(.semibold))
                Text("\(hunt.checkpoints.count) checkpoints\(hunt.hostName.isEmpty ? "" : " · hosted by \(hunt.hostName)")")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
                onPlay?(hunt)
            } label: {
                Text(onPlay == nil ? "Done" : "Play now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            Text(onPlay == nil ? "It's saved in your hunt list." : "It's also saved in your hunt list.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .padding()
    }
}

#Preview {
    JoinView()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
