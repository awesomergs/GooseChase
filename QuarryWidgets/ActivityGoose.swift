import SwiftUI

/// A snapshot-friendly version of the app mascot. Standard rotation transforms
/// animate the legs on content updates; no continuously running timeline is used.
struct ActivityGoose: View {
    var phase: Double

    var body: some View {
        ZStack {
            leg(at: 50)
                .rotationEffect(.degrees(sin(phase) * 28), anchor: UnitPoint(x: 50.0 / 120, y: 0.71))
            leg(at: 62)
                .rotationEffect(.degrees(-sin(phase) * 28), anchor: UnitPoint(x: 62.0 / 120, y: 0.71))
            Canvas { context, size in
                let scale = min(size.width / 120, size.height / 100)
                context.translateBy(x: (size.width - 120 * scale) / 2,
                                    y: (size.height - 100 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                draw(in: context)
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func leg(at hipX: CGFloat) -> some View {
        Canvas { context, size in
            let scale = min(size.width / 120, size.height / 100)
            context.translateBy(x: (size.width - 120 * scale) / 2,
                                y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            var leg = Path()
            leg.move(to: CGPoint(x: hipX, y: 71))
            leg.addLine(to: CGPoint(x: hipX, y: 92.3))
            leg.addLine(to: CGPoint(x: hipX + 7, y: 92.3))
            context.stroke(leg, with: .color(Color(red: 0.949, green: 0.549, blue: 0.157)),
                           style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        }
    }

    private func draw(in context: GraphicsContext) {
        let orange = Color(red: 0.949, green: 0.549, blue: 0.157)
        let ink = Color(red: 0.118, green: 0.165, blue: 0.200)
        let lift: CGFloat = -2
        let head = CGPoint(x: 97, y: 30 + lift)
        let body = CGRect(x: 25, y: 41 + lift, width: 60, height: 34)

        for y in [CGFloat(48), 58, 68] {
            var line = Path()
            line.move(to: CGPoint(x: 4, y: y + lift))
            line.addLine(to: CGPoint(x: 16, y: y + lift))
            context.stroke(line, with: .color(.white.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        var tail = Path()
        tail.move(to: CGPoint(x: 28, y: 52 + lift))
        tail.addLine(to: CGPoint(x: 13, y: 45 + lift))
        tail.addLine(to: CGPoint(x: 26, y: 63 + lift))
        tail.closeSubpath()
        context.fill(tail, with: .color(.white))
        context.fill(Path(ellipseIn: body), with: .color(.white))

        var neck = Path()
        neck.move(to: CGPoint(x: 72, y: 52 + lift))
        neck.addQuadCurve(to: head, control: CGPoint(x: 90, y: 46 + lift))
        context.stroke(neck, with: .color(.white),
                       style: StrokeStyle(lineWidth: 10, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: head.x - 9, y: head.y - 9, width: 18, height: 18)),
                     with: .color(.white))

        var wingContext = context
        wingContext.translateBy(x: 64, y: 52 + lift)
        wingContext.rotate(by: .degrees(-6))
        wingContext.fill(Path(ellipseIn: CGRect(x: -34, y: -7, width: 36, height: 16)),
                         with: .color(Color(red: 0.835, green: 0.871, blue: 0.898)))

        var beak = Path()
        beak.move(to: CGPoint(x: head.x + 6, y: head.y - 3))
        beak.addLine(to: CGPoint(x: head.x + 18, y: head.y + 1))
        beak.addLine(to: CGPoint(x: head.x + 6, y: head.y + 4))
        beak.closeSubpath()
        context.fill(beak, with: .color(orange))
        context.fill(Path(ellipseIn: CGRect(x: head.x, y: head.y - 5, width: 3.8, height: 3.8)),
                     with: .color(ink))
    }
}

#Preview {
    ActivityGoose(phase: .pi / 4)
        .frame(width: 120, height: 100)
        .padding()
        .background(.blue)
}
