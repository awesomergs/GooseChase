import SwiftUI
import SwiftData

/// A compact fact that grows with Dynamic Type.
struct QuarryMetricView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let value: Text
    let systemImage: String

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            value
                .font(.system(.title2, design: .rounded).bold())
                .monospacedDigit()
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.card, in: .rect(cornerRadius: QuarryTheme.cardRadius))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    QuarryMetricView(title: "Checkpoints", value: Text("3"), systemImage: "flag")
        .padding()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
