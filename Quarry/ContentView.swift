//
//  ContentView.swift  ·  OWNER: Rohan (restructured into tabs)
//  App shell: three tabs (Join | Host | Create) plus the shared game launcher
//  (countdown + full-screen PlayView) and incoming links/files.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case join, host, create
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var selection: AppTab = .join
    @State private var game: GameLaunch?
    @State private var incomingPackage: IncomingPackage?
    /// Room code from a quarry://join link (iPhone Camera app scanned the host's QR).
    @State private var linkCode: String?

    var body: some View {
        TabView(selection: $selection) {
            Tab("Join", systemImage: "qrcode.viewfinder", value: AppTab.join) {
                JoinTab(linkCode: $linkCode, onStart: launch)
            }
            Tab("Host", systemImage: "dot.radiowaves.left.and.right", value: AppTab.host) {
                HostTab(onStart: launch, onCreateHunt: { selection = .create })
            }
            Tab("Create", systemImage: "plus.square.on.square", value: AppTab.create) {
                CreateTab(onPlay: { hunt in launch(hunt, nil) })
            }
        }
        .fullScreenCover(item: $game) { launch in
            PlayView(session: launch.session, startAt: launch.startAt) {
                finish(launch)
            }
        }
        // AirDrop / Messages: a .quarryhunt file was opened
        .sheet(item: $incomingPackage) { incoming in
            ImportHuntSheet(package: incoming.package) {
                incomingPackage = nil
                selection = .join
            } onCancel: {
                incomingPackage = nil
            }
        }
        .onOpenURL { url in
            if let code = RoomCode.code(from: url) {
                selection = .join
                linkCode = code
            } else if url.isFileURL, let pkg = try? HuntPackage.load(from: url) {
                incomingPackage = IncomingPackage(package: pkg)
            }
            // quarry://camera is handled by PlayView while a game is running.
        }
        .onAppear { DemoData.seedIfEmpty(context) }
        .task { await LiveActivityManager.shared.endAllStale() }
    }

    // MARK: - Game launcher

    /// Starts a game. `startAt` = synced start time (shows a 3-2-1 countdown); nil = start now.
    private func launch(_ hunt: Hunt, _ startAt: Date?) {
        let session = HuntSession(hunt: hunt)
        if startAt == nil { session.start() }   // PlayView starts it after the countdown otherwise
        game = GameLaunch(session: session, startAt: startAt)
    }

    /// Records the result (for "Your games") and tears down any nearby connection.
    private func finish(_ launch: GameLaunch) {
        let session = launch.session
        if session.isFinished {
            let hunt = session.hunt
            hunt.lastPlayedAt = .now
            let time = session.totalTime
            hunt.bestTime = min(hunt.bestTime ?? .infinity, time)
        }
        NearbySession.shared.stop()
        game = nil
    }
}

/// A game being played (identifiable so it can drive .fullScreenCover(item:)).
struct GameLaunch: Identifiable {
    let id = UUID()
    let session: HuntSession
    let startAt: Date?
}

/// Small helpers shared by the tabs.
@ViewBuilder
func huntThumbnail(_ data: Data?, size: CGFloat = 44) -> some View {
    if let data, let image = UIImage(data: data) {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    } else {
        Image(systemName: "flag.fill")
            .foregroundStyle(.indigo)
            .frame(width: size, height: size)
            .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.2))
    }
}

private struct IncomingPackage: Identifiable {
    var id: UUID { package.shareID }
    let package: HuntPackage
}

// MARK: - Import confirmation sheet

private struct ImportHuntSheet: View {
    let package: HuntPackage
    let onImported: () -> Void
    let onCancel: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo)
                Text("Join \"\(package.title)\"?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(package.checkpoints.count) checkpoints · from \(package.hostName.isEmpty ? "someone" : package.hostName)")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("New Hunt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        let hunt = package.importHunt(into: context)
                        hunt.isJoined = true
                        try? context.save()
                        onImported()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
