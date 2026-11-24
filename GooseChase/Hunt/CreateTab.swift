//
//  CreateTab.swift  ·  Create tab: the hunts you made. Edit, play solo, share, delete.
//  (Joined hunts never show here; they're under "Your games" in the Join tab.)
//

import SwiftUI
import SwiftData

struct CreateTab: View {
    let onPlay: (Hunt) -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Hunt> { !$0.isJoined }, sort: \Hunt.createdAt, order: .reverse)
    private var hunts: [Hunt]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                HuntTabHeader(title: "Make a little adventure", subtitle: "Hide it. Snap it. Write a clue.")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                Button(action: newHunt) {
                    Label("New hunt", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .gooseProminent()
                .foregroundStyle(Brand.ink)
                .padding(.horizontal, 16)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Text("Your hunts")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)

                if hunts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A great chase starts with a clue")
                            .font(.headline)
                        Text("Tap New hunt, then add checkpoints with photos of the things you want friends to find.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(hunts) { hunt in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            HuntRow(hunt: hunt)
                            Spacer(minLength: 0)
                            if hunt.isPlayable {
                                Button {
                                    onPlay(hunt)
                                } label: {
                                    Label("Play solo", systemImage: "play.fill")
                                        .labelStyle(.iconOnly)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .tint(Brand.ink)
                                .accessibilityLabel("Play \(hunt.title) solo")
                            }
                        }
                        NavigationLink(value: hunt) {
                            Text(hunt.isPlayable ? "Edit hunt" : "Continue editing")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(Brand.ink)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading) {
                        Button("Edit", systemImage: "pencil") { path.append(hunt) }
                            .tint(Brand.sky)
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
            .listStyle(.plain)
            .listRowSpacing(12)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(HuntTabBackground())
            .navigationTitle("Your hunts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(path.isEmpty ? .hidden : .visible, for: .navigationBar)
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

#Preview {
    CreateTab(onPlay: { _ in })
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
