//
//  CreateTab.swift  ·  Create tab: the hunts you made. Edit, play solo, share, delete.
//  (Joined hunts never show here; they're under "Your games" in the Join tab.)
//

import SwiftUI
import SwiftData

struct CreateTab: View {
    let onPlay: (Hunt) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Hunt> { !$0.isJoined }, sort: \Hunt.createdAt, order: .reverse)
    private var hunts: [Hunt]
    @State private var path = NavigationPath()

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        NavigationStack(path: $path) {
            List {
                if !hunts.isEmpty {
                    HStack(spacing: 16) {
                        Text("Your hunts")
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image("d f")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .shadow(color: .black.opacity(0.45), radius: 0.75, y: 1)
                            .rotationEffect(.degrees(-8))
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(hunts) { hunt in
                    HuntListRow(hunt: hunt) {
                        if hunt.isPlayable { onPlay(hunt) }
                    }
                    .modifier(QuarryCardRow())
                    .accessibilityAction(named: Text("Edit hunt")) {
                        path.append(hunt)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Edit", systemImage: "pencil") { path.append(hunt) }
                            .tint(theme.accent)
                        if hunt.isPlayable {
                            Button {
                                onPlay(hunt)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(hunt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        if hunt.isPlayable {
                            Button {
                                onPlay(hunt)
                            } label: {
                                Label("Play solo", systemImage: "play.fill")
                            }
                            ShareLink(
                                item: HuntPackage(hunt: hunt),
                                preview: SharePreview(hunt.title, image: Image(systemName: "flag.fill"))
                            ) {
                                Label("Share (AirDrop)", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button(role: .destructive) {
                            context.delete(hunt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listRowSpacing(QuarryTheme.cardSpacing)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .overlay {
                if hunts.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 8) {
                            GooseView(mood: .waiting)
                                .frame(height: 110)
                            Text("No hunts yet")
                        }
                    } description: {
                        Text("Snap a few photos of hidden things and write clues to make your first hunt.")
                    } actions: {
                        Button("New hunt", action: newHunt)
                            .gooseProminent()
                    }
                }
            }
            .pageBackground()
            .navigationTitle("My Hunts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New hunt", systemImage: "plus", action: newHunt)
                        .tint(theme.primaryText)
                }
            }
            .navigationDestination(for: Hunt.self) { hunt in
                HuntEditorView(hunt: hunt, path: $path)
            }
            .navigationDestination(for: Checkpoint.self) { checkpoint in
                CheckpointEditorView(checkpoint: checkpoint)
            }
        }
    }

    private func newHunt() {
        let hunt = Hunt(title: "New Hunt")
        hunt.hostName = PlayerIdentity.name
        context.insert(hunt)
        path.append(hunt)
    }
}

/// One hunt in a list: thumbnail, title, checkpoint count, and a setup warning if needed.
struct HuntRow: View {
    let hunt: Hunt

    var body: some View {
        HStack(spacing: 12) {
            huntThumbnail(hunt.orderedCheckpoints.first?.thumbnail)
            VStack(alignment: .leading, spacing: 2) {
                Text(hunt.title)
                    .font(.headline)
                Text("\(hunt.checkpoints.count) checkpoint\(hunt.checkpoints.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !hunt.isPlayable {
                    Label(hunt.checkpoints.isEmpty ? "Add checkpoints" : "Needs photos",
                          systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
