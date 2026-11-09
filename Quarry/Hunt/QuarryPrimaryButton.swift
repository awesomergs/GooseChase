import SwiftUI
import SwiftData

struct QuarryPrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.vertical, 4)
                .foregroundStyle(theme.onAccent)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(theme.accent)
    }
}

#Preview {
    QuarryPrimaryButton(title: "Create hunt", systemImage: "plus") {}
        .padding()
        .modelContainer(for: [Hunt.self, Checkpoint.self], inMemory: true)
}
