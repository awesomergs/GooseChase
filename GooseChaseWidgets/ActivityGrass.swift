import SwiftUI

/// Flat beneath the goose's feet, with a gentle hill across the rest of the card.
struct ActivityGrass: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 8))
        path.addLine(to: CGPoint(x: min(110, rect.width * 0.35), y: 8))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: 8),
            control1: CGPoint(x: rect.width * 0.55, y: -3),
            control2: CGPoint(x: rect.width * 0.75, y: 18)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ActivityGrass()
        .fill(.green)
        .frame(height: 30)
}
