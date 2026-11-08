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

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(hunts) { hunt in
                    Button {
                        let s = HuntSession(hunt: hunt)
                        s.start()
                        session = s
                    } label: {
                        HStack(spacing: 12) {
                            thumbnail(for: hunt.orderedCheckpoints.first?.thumbnail)
                            VStack(alignment: .leading) {
                                Text(hunt.title).font(.headline)
                                Text("\(hunt.checkpoints.count) checkpoints").font(.subheadline).foregroundStyle(.secondary)
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
                    }
                }
            }
            .navigationTitle("Quarry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New hunt", systemImage: "plus") {
                        let hunt = Hunt(title: "New Hunt")
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
            .fullScreenCover(item: $session) { s in
                PlayView(session: s) { session = nil }
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

extension HuntSession: Identifiable {}

struct PlayView: View {
    @Bindable var session: HuntSession
    let onClose: () -> Void
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let cp = session.current {
                    Text("Checkpoint \(session.progressText)")
                        .font(.headline).foregroundStyle(.secondary)
                    Text(cp.clue)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Button {
                        showCamera = true
                    } label: {
                        Label("Open camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Image(systemName: "flag.checkered").font(.system(size: 56))
                    Text("Hunt complete!").font(.largeTitle.bold())
                    Text(session.startDate, style: .timer).font(.title.monospacedDigit())
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End", systemImage: "xmark") {
                        if session.current != nil { session.quit() }
                        onClose()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                if let cp = session.current {
                    VerifyCameraView(checkpoint: cp) {
                        showCamera = false
                        session.clearCurrent()
                    }
                }
            }
            // Tapping the Live Activity / Dynamic Island opens quarry://camera
            .onOpenURL { url in
                if url.host == "camera", session.current != nil { showCamera = true }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
