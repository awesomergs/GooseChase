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

    var body: some View {
        NavigationStack {
            List(hunts) { hunt in
                Button {
                    let s = HuntSession(hunt: hunt)
                    s.start()
                    session = s
                } label: {
                    VStack(alignment: .leading) {
                        Text(hunt.title).font(.headline)
                        Text("\(hunt.checkpoints.count) checkpoints").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Quarry")
            .fullScreenCover(item: $session) { s in
                PlayView(session: s) { session = nil }
            }
        }
        .onAppear { DemoData.seedIfEmpty(context) }
        .task { await LiveActivityManager.shared.endAllStale() }
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
