import SwiftUI

/// The tab landing pages share the hunt's sky, grass, and running mascot.
struct HuntTabHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
            GooseView(mood: .running)
                .frame(width: 132, height: 110)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Brand.sky, Brand.skyLight],
                           startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    // Anchor the ground to the scene, beneath the goose's feet.
                    GrassHill()
                        .frame(height: 42)
                }
                .clipShape(HuntTabSceneShape())
        }
    }
}

#Preview {
    HuntTabHeader(title: "Join a hunt", subtitle: "Your next chase starts here.")
}
