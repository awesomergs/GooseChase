import SwiftUI
import SwiftData

/// Actual hunt progress, never reference-photo setup readiness.
struct QuarryProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    let cleared: Int
    let total: Int

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Hunt progress", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Spacer()
                Text("\(min(cleared, total))/\(total)")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            if total > 0 && total <= 12 {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { index in
                        Capsule()
                            .fill(index < cleared ? theme.verified : (index == cleared ? theme.accent : theme.sand))
                            .frame(height: index == cleared ? 8 : 5)
                    }
                }
                .accessibilityHidden(true)
            } else {
                ProgressView(value: Double(cleared), total: Double(max(total, 1)))
                    .tint(theme.verified)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cleared) of \(total) checkpoints cleared")
    }
}

#Preview {
    QuarryProgressView(cleared: 2, total: 5)
        .padding()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
