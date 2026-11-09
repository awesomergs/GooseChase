import SwiftUI
import SwiftData

struct HuntListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let hunt: Hunt
    let onStart: () -> Void

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        let readyCount = hunt.checkpoints.count(where: \.isReady)

        VStack(alignment: .leading, spacing: QuarryTheme.cardPadding) {
            // Preserve the original tap-to-start behavior on the hunt summary.
            Button(action: onStart) {
                HStack(alignment: .top, spacing: QuarryTheme.cardSpacing) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HuntThumbnail(data: hunt.orderedCheckpoints.first?.thumbnail)
                    }
                    VStack(alignment: .leading, spacing: QuarryTheme.relatedSpacing) {
                        if dynamicTypeSize.isAccessibilitySize {
                            HuntThumbnail(data: hunt.orderedCheckpoints.first?.thumbnail)
                        }
                        Text(hunt.title)
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(hunt.checkpoints.count) checkpoints")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                        if hunt.checkpoints.isEmpty {
                            Text("Add checkpoints in Edit to prepare this hunt.")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        } else {
                            // Setup readiness is not saved player progress or camera verification.
                            Text("Setup: \(readyCount) of \(hunt.checkpoints.count) ready")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hunt.isPlayable)
            .accessibilityHint("Starts this hunt")

            Divider()
            let actionLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            actionLayout {
                NavigationLink(value: hunt) {
                    Label("Details", systemImage: "list.bullet")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                QuarryPrimaryButton(title: "Start hunt", systemImage: "play.fill", action: onStart)
                    .disabled(!hunt.isPlayable)
                    .accessibilityLabel(Text("Start \(hunt.title)"))
            }
        }
    }
}

#Preview("Hunt card") {
    List {
        HuntListRow(hunt: Hunt(title: "An adventure around the neighborhood")) {}
            .modifier(QuarryCardRow())
    }
    .listStyle(.insetGrouped)
    .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
