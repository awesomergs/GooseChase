//
//  Card.swift  ·  Solid content surfaces. Liquid Glass is for controls, never content
//  (see DESIGN.md §8), so every card, panel and non-interactive label here is opaque.
//

import SwiftUI

enum CardStyle {
    case plain   // white on canvas (lists, forms)
    case onSky   // white card, ink text — content sitting on the sky scene
    case tinted  // skyDeep card, white text — content that must stay legible on the sky
}

private struct BrandCard: ViewModifier {
    let style: CardStyle
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(style == .tinted ? Color.white : Brand.textPrimary)
            .background(fill, in: .rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius)
                        .strokeBorder(Brand.textSecondary, lineWidth: 1)
                }
            }
    }

    private var fill: Color {
        switch style {
        case .plain, .onSky: Brand.surface
        case .tinted: Brand.skyDeep
        }
    }
}

extension View {
    /// Solid content card. Never glass — glass is reserved for controls.
    func brandCard(_ style: CardStyle = .plain) -> some View { modifier(BrandCard(style: style)) }

    /// Text-field well used on forms (e.g. the Join form).
    func brandField() -> some View {
        padding(12).background(Color(.tertiarySystemFill), in: .rect(cornerRadius: Metrics.thumbRadius))
    }
}

/// A non-interactive label (split time, rank, running timer). Solid, so it reads as
/// information, not as a tappable control.
struct StatusPill<Label: View>: View {
    var tint: Color = Brand.skyDeep
    @ViewBuilder var label: Label

    var body: some View {
        label
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint, in: Capsule())
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Plain card").brandCard(.plain)
        Text("On-sky card").brandCard(.onSky)
        Text("Tinted card").brandCard(.tinted)
        StatusPill { Label("3:45", systemImage: "stopwatch") }
    }
    .padding()
    .background(SkyBackground())
}
