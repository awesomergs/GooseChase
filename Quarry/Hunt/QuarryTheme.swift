import SwiftUI

/// Presentation tokens owned by the hunt flow; shared model contracts stay unchanged.
struct QuarryTheme {
    let colorScheme: ColorScheme

    var canvas: Color { color(light: 0xFFF9F0, dark: 0x1D1916) }
    var card: Color { color(light: 0xFFFEFB, dark: 0x2B2520) }
    var accent: Color { color(light: 0xFFA138, dark: 0xFFB45C) }
    var sand: Color { color(light: 0xFFF0DF, dark: 0x49392C) }
    var primaryText: Color { color(light: 0x2D2925, dark: 0xFFF9F0) }
    var secondaryText: Color { color(light: 0x746B63, dark: 0xC2B3A5) }
    var verified: Color { color(light: 0x2F6B4F, dark: 0x8EC9A5) }
    var onAccent: Color { color(light: 0x2D2925, dark: 0x2D2925) }

    static let relatedSpacing: CGFloat = 8
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let thumbnailRadius: CGFloat = 12
    static let thumbnailSize: CGFloat = 56
    static let heading: Font = .system(.headline, design: .rounded).bold()

    private func color(light: UInt32, dark: UInt32) -> Color {
        let hex = colorScheme == .dark ? dark : light
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
