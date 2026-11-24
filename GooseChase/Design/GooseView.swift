//
//  GooseView.swift  ·  The GooseChase mascot, drawn in code so it can animate.
//    .running   — joining / connecting / countdown (legs going, bobbing, speed lines)
//    .waiting   — lobby, clue screen, empty states (gentle bob, looks around, blinks)
//    .honk      — checkpoint cleared (beak flapping, honk lines)
//    .celebrate — hunt complete (jumping, wings flapping)
//  Respects Reduce Motion (draws a still goose).
//

import SwiftUI

nonisolated enum GooseMood: Hashable, Sendable {
    case running, waiting, honk, celebrate
}

struct GooseView: View {
    var mood: GooseMood = .waiting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let drawing = GooseDrawing(mood: mood, t: t)
            Canvas { context, size in
                let s = min(size.width / 120, size.height / 100)
                context.translateBy(x: (size.width - 120 * s) / 2, y: (size.height - 100 * s) / 2)
                context.scaleBy(x: s, y: s)
                drawing.draw(context)
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// All the geometry, in a 120 × 100 canvas. The goose faces right; the ground is y = 91.
nonisolated struct GooseDrawing {
    let mood: GooseMood
    let t: Double

    func draw(_ base: GraphicsContext) {
        let outline = Brand.ink.opacity(0.22)
        let ground: CGFloat = 91

        // Pose for this frame
        var lift: CGFloat = 0
        var legSwing: CGFloat = 0
        var wingAngle: Double = -8
        var neckEnd = CGPoint(x: 86, y: 22)
        var neckControl = CGPoint(x: 90, y: 42)
        var beakOpen = false
        var blink = false
        var dangling = false

        switch mood {
        case .running:
            let p = t * 14
            lift = CGFloat(-abs(sin(p)) * 3)
            legSwing = CGFloat(sin(p) * 11)
            neckEnd = CGPoint(x: 97, y: 30)
            neckControl = CGPoint(x: 90, y: 46)
            wingAngle = -6 + sin(p) * 7
        case .waiting:
            lift = CGFloat(sin(t * 2) * 1.2)
            neckEnd = CGPoint(x: 86 + CGFloat(sin(t * 0.9)) * 3, y: 22 + CGFloat(sin(t * 1.3)))
            blink = t.truncatingRemainder(dividingBy: 3.3) < 0.13
        case .honk:
            let p = t * 9
            beakOpen = sin(p) > -0.2
            neckEnd = CGPoint(x: 97 + (beakOpen ? 2 : 0), y: 29)
            neckControl = CGPoint(x: 90, y: 44)
            wingAngle = -14 + sin(p) * 4
        case .celebrate:
            let p = t * 7
            lift = CGFloat(-abs(sin(p)) * 12)
            wingAngle = -45 + sin(p * 2) * 25
            neckEnd = CGPoint(x: 88, y: 18)
            beakOpen = true
            dangling = lift < -2
        }

        let body = CGRect(x: 25, y: 41 + lift, width: 60, height: 34)
        let head = CGPoint(x: neckEnd.x, y: neckEnd.y + lift)
        let neckStart = CGPoint(x: 72, y: 52 + lift)
        let control = CGPoint(x: neckControl.x, y: neckControl.y + lift)

        // Shadow (shrinks as the goose leaves the ground)
        let shadowScale = 1 - min(abs(lift) / 30, 0.5)
        base.fill(Path(ellipseIn: CGRect(x: 55 - 26 * shadowScale, y: ground - 2,
                                         width: 52 * shadowScale, height: 5)),
                  with: .color(.black.opacity(0.12)))

        // Speed lines
        if mood == .running {
            let shift = CGFloat((t * 60).truncatingRemainder(dividingBy: 10))
            for (i, y) in [CGFloat(48), 58, 68].enumerated() {
                var line = Path()
                let x = 2 + shift + CGFloat(i % 2) * 4
                line.move(to: CGPoint(x: x, y: y + lift))
                line.addLine(to: CGPoint(x: x + 12, y: y + lift))
                base.stroke(line, with: .color(.white.opacity(0.85)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }

        // Legs and feet
        for (index, hipX) in [CGFloat(50), CGFloat(62)].enumerated() {
            let hip = CGPoint(x: hipX, y: 71 + lift)
            let swing = index == 0 ? legSwing : -legSwing
            let foot: CGPoint
            if dangling {
                foot = CGPoint(x: hip.x - 3, y: hip.y + 15)
            } else {
                foot = CGPoint(x: hip.x + swing, y: ground - max(0, swing) * 0.35)
            }
            var leg = Path()
            leg.move(to: hip)
            leg.addLine(to: foot)
            leg.move(to: foot)
            leg.addLine(to: CGPoint(x: foot.x + 7, y: foot.y))
            base.stroke(leg, with: .color(Brand.orange),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        }

        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x: 28, y: 52 + lift))
        tail.addLine(to: CGPoint(x: 13, y: 45 + lift))
        tail.addLine(to: CGPoint(x: 26, y: 63 + lift))
        tail.closeSubpath()
        base.fill(tail, with: .color(.white))
        base.stroke(tail, with: .color(outline), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

        // Neck + head outlines (drawn first so the white goes over them)
        var neck = Path()
        neck.move(to: neckStart)
        neck.addQuadCurve(to: head, control: control)
        base.stroke(neck, with: .color(outline), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        base.fill(circle(head, 10.4), with: .color(outline))

        // Body
        base.fill(Path(ellipseIn: body), with: .color(.white))
        base.stroke(Path(ellipseIn: body), with: .color(outline), lineWidth: 1.5)

        // Neck + head
        base.stroke(neck, with: .color(.white), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        base.fill(circle(head, 9), with: .color(.white))

        // Wing (rotates around the shoulder)
        var wingContext = base
        wingContext.translateBy(x: 64, y: 52 + lift)
        wingContext.rotate(by: .degrees(wingAngle))
        let wing = Path(ellipseIn: CGRect(x: -34, y: -7, width: 36, height: 16))
        wingContext.fill(wing, with: .color(Brand.wing))
        wingContext.stroke(wing, with: .color(outline), lineWidth: 1.2)

        // Beak
        if beakOpen {
            var upper = Path()
            upper.move(to: CGPoint(x: head.x + 6, y: head.y - 4))
            upper.addLine(to: CGPoint(x: head.x + 19, y: head.y - 5))
            upper.addLine(to: CGPoint(x: head.x + 7, y: head.y))
            upper.closeSubpath()
            var lower = Path()
            lower.move(to: CGPoint(x: head.x + 7, y: head.y + 1))
            lower.addLine(to: CGPoint(x: head.x + 16, y: head.y + 8))
            lower.addLine(to: CGPoint(x: head.x + 5, y: head.y + 5))
            lower.closeSubpath()
            base.fill(upper, with: .color(Brand.orange))
            base.fill(lower, with: .color(Brand.orange))
        } else {
            var beak = Path()
            beak.move(to: CGPoint(x: head.x + 6, y: head.y - 3))
            beak.addLine(to: CGPoint(x: head.x + 18, y: head.y + 1))
            beak.addLine(to: CGPoint(x: head.x + 6, y: head.y + 4))
            beak.closeSubpath()
            base.fill(beak, with: .color(Brand.orange))
        }

        // Eye
        let eye = CGPoint(x: head.x + 2, y: head.y - 3)
        if blink {
            var lid = Path()
            lid.move(to: CGPoint(x: eye.x - 2, y: eye.y))
            lid.addLine(to: CGPoint(x: eye.x + 2, y: eye.y))
            base.stroke(lid, with: .color(Brand.ink), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        } else {
            base.fill(circle(eye, 1.9), with: .color(Brand.ink))
        }

        // Honk lines
        if mood == .honk && beakOpen {
            let start = CGPoint(x: head.x + 22, y: head.y)
            for angle in [-30.0, 0.0, 30.0] {
                let r = angle * .pi / 180
                var line = Path()
                line.move(to: CGPoint(x: start.x + 2 * cos(r), y: start.y + 2 * sin(r)))
                line.addLine(to: CGPoint(x: start.x + 9 * cos(r), y: start.y + 9 * sin(r)))
                base.stroke(line, with: .color(.white),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
    }

    private func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    }
}

#Preview("Moods") {
    VStack(spacing: 12) {
        HStack {
            GooseView(mood: .running)
            GooseView(mood: .waiting)
        }
        HStack {
            GooseView(mood: .honk)
            GooseView(mood: .celebrate)
        }
    }
    .padding()
    .background(SkyBackground())
}
