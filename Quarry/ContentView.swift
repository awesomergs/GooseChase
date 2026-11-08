//
//  ContentView.swift  ·  OWNER: Person B (hunt flow)
//  Bare-bones starting flow: hunt list → play → camera stub → next clue.
//  Replace freely; it exists so all three of you can test end to end today.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Hunt.createdAt) private var hunts: [Hunt]
    @State private var session: HuntSession?
    @State private var path = NavigationPath()
    @State private var pendingSetupHunt: Hunt?
    @State private var incomingPackage: IncomingPackage?
    // Race entry points
    @State private var hostingContext: HostingContext?
    @State private var joinContext: JoinContext?
    /// Passed to PlayView for synced race starts; nil for solo play.
    @State private var pendingStartAt: Date?
    /// Tracks the in-progress join while waiting for the host to start.
    @State private var pendingJoinInfo: (hunt: Hunt, package: HuntPackage)?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(hunts) { hunt in
                    Button {
                        if hunt.isPlayable {
                            let s = HuntSession(hunt: hunt)
                            s.start()
                            session = s
                        } else {
                            pendingSetupHunt = hunt
                        }
                    } label: {
                        HStack(spacing: 12) {
                            thumbnail(for: hunt.orderedCheckpoints.first?.thumbnail)
                            VStack(alignment: .leading) {
                                Text(hunt.title).font(.headline)
                                Text("\(hunt.checkpoints.count) checkpoints").font(.subheadline).foregroundStyle(.secondary)
                                if !hunt.isPlayable {
                                    Text(hunt.checkpoints.isEmpty ? "Add checkpoints" : "Needs photos")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            path.append(hunt)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(hunt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        if hunt.isPlayable {
                            Button {
                                RaceSession.shared.end()
                                hostingContext = HostingContext(hunt: hunt)
                            } label: {
                                Label("Host race", systemImage: "figure.2.arms.open")
                            }
                            .tint(.indigo)
                            ShareLink(
                                item: HuntPackage(hunt: hunt),
                                preview: SharePreview(hunt.title, image: Image(systemName: "flag.fill"))
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .contextMenu {
                        if hunt.isPlayable {
                            Button {
                                RaceSession.shared.end()
                                hostingContext = HostingContext(hunt: hunt)
                            } label: {
                                Label("Host race", systemImage: "figure.2.arms.open")
                            }
                            ShareLink(
                                item: HuntPackage(hunt: hunt),
                                preview: SharePreview(hunt.title, image: Image(systemName: "flag.fill"))
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button {
                            path.append(hunt)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            context.delete(hunt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Quarry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Join", systemImage: "person.2.badge.plus") {
                        joinContext = JoinContext(initialCode: nil)
                    }
                    .accessibilityLabel("Join race")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New hunt", systemImage: "plus") {
                        let hunt = Hunt(title: "New Hunt")
                        hunt.hostName = PlayerIdentity.name
                        context.insert(hunt)
                        path.append(hunt)
                    }
                }
            }
            .navigationDestination(for: Hunt.self) { hunt in
                HuntEditorView(hunt: hunt, path: $path)
            }
            .navigationDestination(for: Checkpoint.self) { cp in
                CheckpointEditorView(checkpoint: cp)
            }
            // Solo / post-race session presents PlayView (startAt nil = already started).
            // Race host/join session passes pendingStartAt for the countdown.
            .fullScreenCover(item: $session) { s in
                PlayView(session: s, startAt: pendingStartAt) {
                    session = nil
                    pendingStartAt = nil
                }
            }
            .alert("Finish setting up this hunt",
                   isPresented: Binding(get: { pendingSetupHunt != nil },
                                        set: { if !$0 { pendingSetupHunt = nil } }),
                   presenting: pendingSetupHunt) { hunt in
                Button("Edit") { path.append(hunt) }
                Button("Cancel", role: .cancel) {}
            }
            // AirDrop / file-share import sheet
            .sheet(item: $incomingPackage) { incoming in
                ImportHuntSheet(package: incoming.package) {
                    incomingPackage = nil
                } onCancel: {
                    incomingPackage = nil
                }
            }
            // Host lobby: show QR + room code, "Start for everyone"
            .sheet(item: $hostingContext) { hosting in
                HostLobbyView(hunt: hosting.hunt, package: HuntPackage(hunt: hosting.hunt)) { date in
                    let count = hosting.hunt.orderedCheckpoints.count
                    RaceSession.shared.begin(
                        huntShareID: hosting.hunt.shareID,
                        total: count,
                        isHost: true,
                        startAt: date
                    )
                    hostingContext = nil
                    // PlayView will call session.start() after the countdown.
                    let s = HuntSession(hunt: hosting.hunt)
                    pendingStartAt = date
                    session = s
                }
            }
            // Join lobby: enter code, receive hunt, wait for host to start
            .sheet(item: $joinContext) { jc in
                JoinView(initialCode: jc.initialCode) { package in
                    // Hunt received from the host: import it and wait for the start signal.
                    let hunt = package.importHunt(into: context)
                    pendingJoinInfo = (hunt, package)
                }
            }
            // When the host fires the start signal, NearbySession.startAt becomes non-nil.
            .onChange(of: NearbySession.shared.startAt) { _, newStartAt in
                guard let newStartAt, let info = pendingJoinInfo else { return }
                RaceSession.shared.begin(
                    huntShareID: info.package.shareID,
                    total: info.package.checkpoints.count,
                    isHost: false,
                    startAt: newStartAt
                )
                joinContext = nil          // dismiss JoinView
                let s = HuntSession(hunt: info.hunt)
                pendingStartAt = newStartAt
                session = s               // present PlayView with countdown
                pendingJoinInfo = nil
            }
            .onOpenURL { url in
                // Deep link: quarry://join?code=ABCD  (iPhone Camera app scans the QR)
                if let code = RoomCode.code(from: url) {
                    joinContext = JoinContext(initialCode: code)
                // Deep link: incoming .quarryhunt file via AirDrop / Messages
                } else if url.isFileURL, let pkg = try? HuntPackage.load(from: url) {
                    incomingPackage = IncomingPackage(package: pkg)
                }
            }
        }
        .onAppear { DemoData.seedIfEmpty(context) }
        .task { await LiveActivityManager.shared.endAllStale() }
    }

    @ViewBuilder
    private func thumbnail(for data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Private context types

private struct HostingContext: Identifiable {
    let id = UUID()
    let hunt: Hunt
}

private struct JoinContext: Identifiable {
    let id = UUID()
    let initialCode: String?
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
                        package.importHunt(into: context)
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
