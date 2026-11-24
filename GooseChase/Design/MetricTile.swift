import SwiftUI

/// A compact fact that grows with Dynamic Type (checkpoint count, ready-to-play status).
struct MetricTile: View {
    let title: LocalizedStringKey
    let value: Text
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.related) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
            value
                .font(.system(.title2, design: .rounded).bold())
                .monospacedDigit()
                .foregroundStyle(Brand.textPrimary)
        }
        .brandCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MetricTile(title: "Checkpoints", value: Text("3"), systemImage: "flag")
        .padding()
        .background(Brand.canvas)
}
