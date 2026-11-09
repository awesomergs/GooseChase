//
//  HuntEditorView.swift  ·  OWNER: Person B (hunt flow)
//  Edit a hunt's title and its checkpoints: add (pushes the checkpoint editor on the
//  shared root path), swipe to delete, and drag to reorder.
//

import SwiftUI
import SwiftData

struct HuntEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var theme: QuarryTheme { QuarryTheme(colorScheme: colorScheme) }
    @Bindable var hunt: Hunt
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    QuarryMetricView(title: "Checkpoints", value: Text("\(hunt.checkpoints.count)"), systemImage: "flag")
                    QuarryMetricView(title: "Ready to play",
                                     value: Text("\(hunt.checkpoints.count(where: \.isReady)) of \(hunt.checkpoints.count)"),
                                     systemImage: "camera")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Hunt name") {
                TextField("Hunt title", text: $hunt.title, axis: .vertical)
                    .font(.system(.title2, design: .rounded).bold())
                    .padding(.vertical, 8)
            }
            .listRowBackground(theme.card)

            Section("Checkpoints") {
                ForEach(hunt.orderedCheckpoints) { cp in
                    NavigationLink(value: cp) {
                        HStack(spacing: 12) {
                            Text(cp.order + 1, format: .number)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(theme.primaryText)
                                .frame(minWidth: 32, minHeight: 32)
                                .background(theme.sand, in: .circle)
                                .accessibilityLabel("Checkpoint \(cp.order + 1)")
                            thumbnail(for: cp.thumbnail)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(cp.clue.isEmpty ? "New checkpoint" : cp.clue)
                                    .font(.headline)
                                    .foregroundStyle(cp.clue.isEmpty ? theme.secondaryText : theme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Label(cp.isReady ? "Ready to play" : "Needs reference photos",
                                      systemImage: cp.isReady ? "camera.fill" : "camera.badge.ellipsis")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryText)
                            }
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
            .listRowBackground(theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.primaryText)
        .tint(theme.accent)
        .navigationTitle("Hunt details")
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
                .foregroundStyle(theme.secondaryText)
                .frame(width: 44, height: 44)
                .background(theme.sand, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    let schema = Schema([Hunt.self, Checkpoint.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    // Insert both models into the context before relating them, or SwiftData
    // traps in BackingData while resolving the relationship.
    let hunt = Hunt(title: "Birthday Hunt")
    container.mainContext.insert(hunt)
    let cp = Checkpoint(order: 0, clue: "Find the thing that keeps the milk cold.", kind: .exactMatch)
    container.mainContext.insert(cp)
    cp.hunt = hunt
    return NavigationStack {
        HuntEditorView(hunt: hunt, path: $path)
    }
    .modelContainer(container)
}
