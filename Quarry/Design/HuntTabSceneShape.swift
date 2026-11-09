import SwiftUI

/// A shallow curved shoreline softens the header's transition into the page.
struct HuntTabSceneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let curveDepth: CGFloat = min(18, rect.height / 4)
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - curveDepth))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - curveDepth),
            control: CGPoint(x: rect.midX, y: rect.maxY + curveDepth)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HuntTabSceneShape()
        .fill(.green)
        .frame(height: 100)
}
