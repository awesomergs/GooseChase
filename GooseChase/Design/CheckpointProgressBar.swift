import SwiftUI

/// Segments for up to 12 checkpoints, a continuous bar otherwise. One spoken label
/// either way, since the segments themselves are decorative.
struct CheckpointProgressBar: View {
    enum Style { case onSky, onCard }

    let cleared: Int
    let total: Int
    var style: Style = .onSky

    var body: some View {
        Group {
            if total > 0 && total <= 12 {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(color(i))
                            .frame(height: i == cleared ? 8 : 6)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ProgressView(value: Double(cleared), total: Double(max(total, 1)))
                    .tint(style == .onSky ? Brand.grass : Brand.success)
            }
        }
        .animation(.spring(duration: 0.4), value: cleared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cleared) of \(total) checkpoints cleared")
    }

    private func color(_ i: Int) -> Color {
        switch style {
        case .onSky:  i < cleared ? Brand.grass   : (i == cleared ? .white : .white.opacity(0.3))
        case .onCard: i < cleared ? Brand.success : (i == cleared ? Brand.orange : Brand.wing)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        CheckpointProgressBar(cleared: 2, total: 5, style: .onSky)
        CheckpointProgressBar(cleared: 2, total: 5, style: .onCard)
    }
    .padding()
    .background(Brand.canvas)
}
