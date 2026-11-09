//
//  ContentView.swift · OWNER: Person B (hunt flow)
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Hunt.createdAt) private var hunts: [Hunt]
    @State private var session: HuntSession?
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
                    HuntListRow(hunt: hunt) { start(hunt) }
                        .modifier(QuarryCardRow())
                        .swipeActions(edge: .leading) {
                            Button("Edit", systemImage: "pencil") {
                                path.append(hunt)
                            }
                            .tint(theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(hunt)
                            }
                        }
                        .accessibilityAction(named: Text("Edit hunt")) {
                            path.append(hunt)
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
                        Image("d f")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.45), radius: 0.75, y: 1)
                            .accessibilityHidden(true)
                        Text("No hunts yet")
                            .foregroundStyle(theme.primaryText)
                    } description: {
                        Text("Create a hunt and add your first checkpoint.")
                            .foregroundStyle(theme.secondaryText)
                    } actions: {
                        QuarryPrimaryButton(
                            title: "Create hunt", systemImage: "plus", action: createHunt
                        )
                        .frame(maxWidth: 320)
                    }
                }
            }
            .navigationTitle("Quarry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(QuarryTheme(colorScheme: .light).accent, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create hunt", systemImage: "plus", action: createHunt)
                        .tint(QuarryTheme(colorScheme: .light).primaryText)
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
        .tint(theme.accent)
        .onAppear { DemoData.seedIfEmpty(context) }
        .task { await LiveActivityManager.shared.endAllStale() }
    }

    private func createHunt() {
        let hunt = Hunt(title: "New Hunt")
        context.insert(hunt)
        path.append(hunt)
    }

    private func start(_ hunt: Hunt) {
        let newSession = HuntSession(hunt: hunt)
        newSession.start()
        session = newSession
    }
}

extension HuntSession: Identifiable {}

struct PlayView: View {
    @Bindable var session: HuntSession
    let onClose: () -> Void
    @State private var showCamera = false
    @State private var completedAt: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: QuarryTheme.sectionSpacing) {
                    QuarryProgressView(cleared: min(session.currentIndex, session.checkpoints.count),
                                       total: session.checkpoints.count)
                    if let cp = session.current {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("Checkpoint \(session.progressText)", systemImage: "mappin.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.accent)
                            Text(cp.clue)
                                .font(.system(.title, design: .rounded).bold())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .background(theme.card, in: .rect(cornerRadius: QuarryTheme.cardRadius))
                        metrics(finished: false)
                        Label("Point your camera at the object when you find it.", systemImage: "camera")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.sand, in: .rect(cornerRadius: QuarryTheme.cardRadius))
                    } else {
                        VStack(spacing: 16) {
                            Image("d f")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                            .shadow(color: .black.opacity(0.45), radius: 0.75, y: 1)
                                .rotationEffect(.degrees(-8))
                                .accessibilityHidden(true)
                            Text("Hunt complete!")
                                .font(.system(.largeTitle, design: .rounded).bold())
                            Text(session.hunt.title)
                                .font(QuarryTheme.heading)
                            Label("All checkpoints verified", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        metrics(finished: true)
                    }
                    if inlineAction {
                        primaryAction
                    }
                }
                .frame(maxWidth: 600, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if !inlineAction {
                    primaryAction
                        .frame(maxWidth: 600)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(theme.canvas)
                }
            }
            .foregroundStyle(theme.primaryText)
            .background(theme.canvas)
            .navigationTitle(session.hunt.title)
            .navigationBarTitleDisplayMode(.inline)
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
            .tint(theme.accent)
            .onChange(of: session.current == nil, initial: true) { _, complete in
                if complete, completedAt == nil { completedAt = .now }
            }
            // Tapping the Live Activity / Dynamic Island opens quarry://camera
            .onOpenURL { url in
                if url.host == "camera", session.current != nil { showCamera = true }
            }
        }
    }

    private var inlineAction: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    @ViewBuilder
    private var primaryAction: some View {
        if session.current != nil {
            QuarryPrimaryButton(title: "Open camera", systemImage: "camera.fill") {
                showCamera = true
            }
        } else {
            QuarryPrimaryButton(title: "Done", systemImage: "checkmark", action: onClose)
        }
    }

    private func metrics(finished: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            QuarryMetricView(title: "Cleared",
                             value: Text("\(min(session.currentIndex, session.checkpoints.count)) of \(session.checkpoints.count)"),
                             systemImage: "flag.checkered")
            QuarryMetricView(title: finished ? "Total time" : "Elapsed",
                             value: Text(timerInterval: session.startDate...Date.distantFuture,
                                         pauseTime: finished ? completedAt : nil, countsDown: false),
                             systemImage: "clock")
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

#Preview("Accessibility") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility5)
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

#Preview("Active clue") {
    let hunt = Hunt(title: "Birthday Hunt")
    let checkpoint = Checkpoint(order: 0, clue: "Find the fountain beside the old oak. Look for the little bird perched on its rim.", kind: .exactMatch)
    hunt.checkpoints = [checkpoint]
    return PlayView(session: HuntSession(hunt: hunt), onClose: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}

#Preview("Completion") {
    PlayView(session: HuntSession(hunt: Hunt(title: "Birthday Hunt")), onClose: {})
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
