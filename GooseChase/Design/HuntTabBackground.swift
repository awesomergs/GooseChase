import SwiftUI

/// Keeps the status-bar area sky blue while the scrolling page stays pale blue.
struct HuntTabBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .overlay(Brand.sky.opacity(0.12))
                    .ignoresSafeArea()

                // Paint outside the list's bounds without moving its content
                // underneath the status bar or changing the native tab bar.
                Brand.sky
                    .frame(height: geometry.safeAreaInsets.top + 1)
                    .offset(y: -geometry.safeAreaInsets.top)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    Color.clear.background(HuntTabBackground())
}
