//
//  Theme.swift  ·  GooseChase look: colors from the app icon, the sky + grass scene,
//  glass cards, and the orange main-action button.
//  Rule of thumb: iOS decides how things work; this file decides how they look.
//    • sky    = tint and backgrounds
//    • orange = the ONE main action on a screen (Scan QR, Snap it, Start for everyone)
//    • grass  = cleared / done
//

import SwiftUI

nonisolated enum Brand {
    static let sky       = Color(red: 0.247, green: 0.635, blue: 0.878)  // #3FA2E0
    static let skyLight  = Color(red: 0.357, green: 0.722, blue: 0.925)  // #5BB8EC
    static let orange    = Color(red: 0.949, green: 0.549, blue: 0.157)  // #F28C28
    static let grass     = Color(red: 0.365, green: 0.733, blue: 0.388)  // #5DBB63
    static let grassDark = Color(red: 0.298, green: 0.647, blue: 0.329)  // #4CA554
    static let ink       = Color(red: 0.118, green: 0.165, blue: 0.200)  // #1E2A33
    static let wing      = Color(red: 0.835, green: 0.871, blue: 0.898)  // #D5DEE5
}

// MARK: - Backgrounds

/// Full-screen sky with a strip of rolling grass at the bottom (play, lobby, cleared, finished).
struct SkyBackground: View {
    var grassHeight: CGFloat = 70

    var body: some View {
        LinearGradient(colors: [Brand.sky, Brand.skyLight], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                if grassHeight > 0 {
                    GrassHill()
                        .frame(height: grassHeight)
                }
            }
            .ignoresSafeArea()
    }
}

/// Small sky scene used as a card background (the Join tab hero).
struct SkyCardBackground: View {
    var body: some View {
        LinearGradient(colors: [Brand.sky, Brand.skyLight], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                GrassHill().frame(height: 18)
            }
    }
}

/// Grass with a gentle wavy top edge and a darker rim.
struct GrassHill: View {
    var body: some View {
        ZStack(alignment: .top) {
            GrassShape().fill(Brand.grassDark)
            GrassShape().fill(Brand.grass).offset(y: 7)
        }
        .clipped()
    }
}

nonisolated struct GrassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bumps = 4
        let w = rect.width / CGFloat(bumps)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        for i in 0..<bumps {
            let x0 = rect.minX + CGFloat(i) * w
            p.addQuadCurve(to: CGPoint(x: x0 + w, y: rect.minY + 8),
                           control: CGPoint(x: x0 + w / 2, y: rect.minY - 4))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Behind lists (Join form, Host, Create): a soft sky wash fading into the normal grouped background.
struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Brand.sky.opacity(0.28), Color(.systemGroupedBackground)],
            startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)
        )
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

// MARK: - Modifiers

extension View {
    /// The one main action on a screen: orange Liquid Glass, large.
    func gooseProminent(_ color: Color = Brand.orange) -> some View {
        self
            .buttonStyle(.glassProminent)
            .tint(color)
            .controlSize(.large)
    }

    /// A Liquid Glass card for content sitting on the sky.
    func skyCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// List background for the tab screens.
    func pageBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PageBackground())
    }
}
