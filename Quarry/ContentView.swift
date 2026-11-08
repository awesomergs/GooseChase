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

#Preview {
    ContentView()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
