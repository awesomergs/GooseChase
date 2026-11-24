//
//  Theme.swift  ·  GooseChase look: colors from the app icon, the sky + grass scene,
//  and the orange main-action button.
//  Rule of thumb: iOS decides how things work; this file decides how they look.
//    • sky    = tint and backgrounds
//    • orange = the ONE main action on a screen (Scan QR, Snap it, Start for everyone)
//    • grass  = cleared / done
//

import SwiftUI

nonisolated enum Brand {
    // Icon colors
    static let sky       = Color(red: 0.247, green: 0.635, blue: 0.878)  // #3FA2E0
    static let skyLight  = Color(red: 0.357, green: 0.722, blue: 0.925)  // #5BB8EC
    static let skyDeep   = Color(red: 0.122, green: 0.435, blue: 0.647)  // #1F6FA5  white text 5.4:1
    static let orange    = Color(red: 0.949, green: 0.549, blue: 0.157)  // #F28C28  the ONE main action
    static let grass     = Color(red: 0.365, green: 0.733, blue: 0.388)  // #5DBB63  decoration / cleared
    static let grassDark = Color(red: 0.298, green: 0.647, blue: 0.329)  // #4CA554
    static let ink       = Color(red: 0.118, green: 0.165, blue: 0.200)  // #1E2A33
    static let wing      = Color(red: 0.835, green: 0.871, blue: 0.898)  // #D5DEE5

    // Semantic roles (the app window is light-only; GooseChaseApp forces .light)
    static let canvas        = Color(red: 0.957, green: 0.976, blue: 0.992) // #F4F9FD  sky-tinted page
    static let surface       = Color.white                                  // cards
    static let textPrimary   = ink
    static let textSecondary = Color(red: 0.357, green: 0.420, blue: 0.463) // #5B6B76  on canvas/surface
    static let success       = Color(red: 0.184, green: 0.478, blue: 0.227) // #2F7A3A  text-safe green
    static let warning       = Color.orange

    /// Camera overlays sit on live video: always a dark scrim behind white text.
    nonisolated enum Camera {
        static let scrim   = Color.black.opacity(0.8)   // 1.0 with Reduce Transparency
        static let text    = Color.white
        static let accent  = Brand.orange
        static let success = Color(red: 0.557, green: 0.788, blue: 0.647) // #8EC9A5 on black
    }
}

nonisolated enum Metrics {
    static let related: CGFloat = 8
    static let item: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let section: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let thumbRadius: CGFloat = 12
    static let thumbSize: CGFloat = 56
    static let minTap: CGFloat = 44
    static let heading: Font = .system(.headline, design: .rounded).bold()
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

// MARK: - Modifiers

extension View {
    /// The main action uses a solid fill to keep its label readable over the scene.
    func gooseProminent(_ color: Color = Brand.orange) -> some View {
        self
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(color)
            .foregroundStyle(Brand.ink)
            .controlSize(.large)
    }
}
