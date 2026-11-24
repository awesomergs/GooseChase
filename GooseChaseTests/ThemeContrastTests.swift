//
//  ThemeContrastTests.swift  ·  GooseChaseTests
//  WCAG contrast for every text/background pair the merged Brand theme actually uses
//  (main button, cards, tinted cards, success labels). Large-headline-on-sky pairs
//  (e.g. "Hunt complete!" directly on Brand.sky) are a deliberate exception documented
//  in docs/phase0/THEME_MERGE_PLAN.md §1d and are checked by hand, not here.
//

import SwiftUI
import Testing
@testable import GooseChase

@MainActor
private func relativeLuminance(_ color: Color) -> Double {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    func channel(_ c: CGFloat) -> Double {
        let c = Double(c)
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}

@MainActor
private func contrastRatio(_ a: Color, _ b: Color) -> Double {
    let l1 = relativeLuminance(a)
    let l2 = relativeLuminance(b)
    let lighter = max(l1, l2), darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
}

@MainActor
@Suite("Brand theme contrast (WCAG AA)")
struct ThemeContrastTests {

    /// 4.5:1 for body text pairs used on brandCard/StatusPill/the main button.
    @Test("Body text pairs meet 4.5:1", arguments: [
        ("ink on orange (gooseProminent label)", Brand.ink, Brand.orange),
        ("ink on white (brandCard .plain/.onSky text)", Brand.ink, Color.white),
        ("textPrimary on surface", Brand.textPrimary, Brand.surface),
        ("textPrimary on canvas", Brand.textPrimary, Brand.canvas),
        ("textSecondary on surface", Brand.textSecondary, Brand.surface),
        ("textSecondary on canvas", Brand.textSecondary, Brand.canvas),
        ("white on skyDeep (brandCard .tinted / StatusPill)", Color.white, Brand.skyDeep),
        ("success on surface", Brand.success, Brand.surface),
        ("success on canvas", Brand.success, Brand.canvas),
    ])
    func bodyTextMeetsAA(name: String, foreground: Color, background: Color) {
        let ratio = contrastRatio(foreground, background)
        #expect(ratio >= 4.5, "\(name): \(ratio)")
    }

    /// Large/bold headline text (≥3:1) placed directly on Brand.wing/skyDeep (not the raw sky).
    @Test("Large text on skyDeep meets 3:1")
    func largeTextOnSkyDeepMeetsAA() {
        let ratio = contrastRatio(.white, Brand.skyDeep)
        #expect(ratio >= 3.0, "white on skyDeep: \(ratio)")
    }

    @Test("White text directly on Brand.sky is the documented exception, not a regression")
    func whiteOnSkyIsKnownException() {
        // Tracked in THEME_MERGE_PLAN.md §1d: large headlines on the raw sky (e.g. "Hunt
        // complete!") stay below 3:1 on purpose and are mitigated with a shadow, checked
        // by hand with Increased Contrast. This test documents the number so a future
        // change to Brand.sky can't silently make it worse without someone noticing.
        let ratio = contrastRatio(.white, Brand.sky)
        #expect(ratio < 3.0)
        #expect(ratio > 2.5)
    }
}
