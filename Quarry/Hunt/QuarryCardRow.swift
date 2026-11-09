import SwiftUI

/// A solid content surface for native List rows, without altering navigation chrome.
struct QuarryCardRow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let theme = QuarryTheme(colorScheme: colorScheme)
        content
            .listRowInsets(EdgeInsets(
                top: QuarryTheme.cardPadding, leading: QuarryTheme.cardPadding,
                bottom: QuarryTheme.cardPadding, trailing: QuarryTheme.cardPadding
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: QuarryTheme.cardRadius)
                    .fill(theme.card)
                    .overlay {
                        if contrast == .increased {
                            RoundedRectangle(cornerRadius: QuarryTheme.cardRadius)
                                .strokeBorder(theme.secondaryText, lineWidth: 1)
                        }
                    }
            )
    }
}
