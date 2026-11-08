//
//  HuntEditorView.swift  ·  OWNER: Person B (hunt flow)
//  Edit a hunt's title and its checkpoints: add (pushes the checkpoint editor on the
//  shared root path), swipe to delete, and drag to reorder.
//

import SwiftUI
import SwiftData

struct HuntEditorView: View {
    @Bindable var hunt: Hunt
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("Title") {
                TextField("Hunt title", text: $hunt.title)
            }

            Section("Checkpoints") {
                ForEach(hunt.orderedCheckpoints) { cp in
                    NavigationLink(value: cp) {
                        HStack(spacing: 12) {
                            thumbnail(for: cp.thumbnail)
                            Text(cp.clue.isEmpty ? "New checkpoint" : cp.clue)
                                .foregroundStyle(cp.clue.isEmpty ? .secondary : .primary)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete(perform: deleteCheckpoints)
                .onMove(perform: moveCheckpoints)

                Button {
                    addCheckpoint()
                } label: {
                    Label("Add checkpoint", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Edit Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onDisappear(perform: cleanupIfEmpty)
    }

    // MARK: - Actions

    private func addCheckpoint() {
        let nextOrder = (hunt.checkpoints.map(\.order).max() ?? -1) + 1
        let cp = Checkpoint(order: nextOrder, clue: "", kind: .exactMatch)
        cp.hunt = hunt
        hunt.checkpoints.append(cp)
        context.insert(cp)
        path.append(cp)   // opens CheckpointEditorView via the root navigationDestination
    }

    private func deleteCheckpoints(at offsets: IndexSet) {
        let ordered = hunt.orderedCheckpoints
        let toDelete = offsets.map { ordered[$0] }
        for cp in toDelete { context.delete(cp) }
        // Renormalize the remaining checkpoints to a contiguous 0..<n order.
        let remaining = ordered.filter { !toDelete.contains($0) }
        for (i, cp) in remaining.enumerated() { cp.order = i }
    }

    private func moveCheckpoints(from source: IndexSet, to destination: Int) {
        var ordered = hunt.orderedCheckpoints
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, cp) in ordered.enumerated() { cp.order = i }
    }

    /// If the user tapped "+" then backed out without doing anything, drop the empty hunt.
    private func cleanupIfEmpty() {
        if hunt.title == "New Hunt" && hunt.checkpoints.isEmpty {
            context.delete(hunt)
        }
    }

    // MARK: - Subviews

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

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    let schema = Schema([Hunt.self, Checkpoint.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    let hunt = Hunt(title: "Birthday Hunt")
    let cp = Checkpoint(order: 0, clue: "Find the thing that keeps the milk cold.", kind: .exactMatch)
    cp.hunt = hunt
    hunt.checkpoints.append(cp)
    container.mainContext.insert(hunt)
    return NavigationStack {
        HuntEditorView(hunt: hunt, path: $path)
    }
    .modelContainer(container)
}
