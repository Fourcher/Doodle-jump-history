import UIKit
import SpriteKit

/// All game art is drawn here, in code, at launch. Nothing is loaded from
/// image files (except the app icon). The style is "ballpoint doodle on
/// graph paper": every shape is filled flat and then outlined with a
/// deliberately shaky ink stroke. A seeded generator keeps the shakes
/// stable from run to run.
enum ArtFactory {

    // MARK: palette

    static let ink = UIColor(red: 0.28, green: 0.20, blue: 0.11, alpha: 1)
    static let paper = UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1)
    static let gridBlue = UIColor(red: 0.77, green: 0.84, blue: 0.90, alpha: 1)
    static let bodyGreen = UIColor(red: 0.66, green: 0.82, blue: 0.26, alpha: 1)
    static let bodyGreenDark = UIColor(red: 0.50, green: 0.66, blue: 0.16, alpha: 1)
    static let platformGreen = UIColor(red: 0.45, green: 0.78, blue: 0.28, alpha: 1)
    static let platformBlue = UIColor(red: 0.35, green: 0.62, blue: 0.93, alpha: 1)
    static let platformBrown = UIColor(red: 0.72, green: 0.52, blue: 0.30, alpha: 1)
    static let platformWhite = UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
    static let monsterPurple = UIColor(red: 0.62, green: 0.44, blue: 0.80, alpha: 1)
    static let monsterTeal = UIColor(red: 0.30, green: 0.70, blue: 0.72, alpha: 1)

    // MARK: deterministic wobble

    private struct Wobble {
        var state: UInt64
        init(seed: UInt64) { state = (seed &* 2654435761) | 1 }
        mutating func unit() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        mutating func spread(_ r: CGFloat) -> CGFloat { (unit() * 2 - 1) * r }
    }

    // MARK: drawing helpers

    private static func ellipsePoints(in rect: CGRect, steps: Int = 40) -> [CGPoint] {
        let cx = rect.midX, cy = rect.midY
        let rx = rect.width / 2, ry = rect.height / 2
        return (0...steps).map { i in
            let a = 2 * .pi * CGFloat(i) / CGFloat(steps)
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    private static func roundedRectPoints(in rect: CGRect, radius: CGFloat,
                                          stepsPerSide: Int = 8) -> [CGPoint] {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        var pts: [CGPoint] = []
        let total = stepsPerSide * 8
        for i in 0...total {
            let t = CGFloat(i) / CGFloat(total)
            pts.append(pointOnPath(path.cgPath, at: t))
        }
        return pts
    }

    /// Cheap arc-length walk along a path for resampling.
    private static func pointOnPath(_ path: CGPath, at t: CGFloat) -> CGPoint {
        var segments: [(CGPoint, CGPoint)] = []
        var current = CGPoint.zero
        var start = CGPoint.zero
        path.applyWithBlock { elem in
            let e = elem.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]; start = current
            case .addLineToPoint:
                segments.append((current, e.points[0])); current = e.points[0]
            case .addQuadCurveToPoint:
                let c = e.points[0], p = e.points[1]
                var prev = current
                for i in 1...6 {
                    let u = CGFloat(i) / 6
                    let q = CGPoint(
                        x: (1 - u) * (1 - u) * current.x + 2 * (1 - u) * u * c.x + u * u * p.x,
                        y: (1 - u) * (1 - u) * current.y + 2 * (1 - u) * u * c.y + u * u * p.y)
                    segments.append((prev, q)); prev = q
                }
                current = p
            case .addCurveToPoint:
                let c1 = e.points[0], c2 = e.points[1], p = e.points[2]
                var prev = current
                for i in 1...8 {
                    let u = CGFloat(i) / 8
                    let mu = 1 - u
                    let q = CGPoint(
                        x: mu * mu * mu * current.x + 3 * mu * mu * u * c1.x + 3 * mu * u * u * c2.x + u * u * u * p.x,
                        y: mu * mu * mu * current.y + 3 * mu * mu * u * c1.y + 3 * mu * u * u * c2.y + u * u * u * p.y)
                    segments.append((prev, q)); prev = q
                }
                current = p
            case .closeSubpath:
                segments.append((current, start)); current = start
            @unknown default:
                break
            }
        }
        let lengths = segments.map { hypot($0.1.x - $0.0.x, $0.1.y - $0.0.y) }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return current }
        var goal = t * total
        for (seg, len) in zip(segments, lengths) {
            if goal <= len {
                let u = len > 0 ? goal / len : 0
                return CGPoint(x: seg.0.x + (seg.1.x - seg.0.x) * u,
                               y: seg.0.y + (seg.1.y - seg.0.y) * u)
            }
            goal -= len
        }
        return segments.last?.1 ?? current
    }

    private static func fillAndInk(_ ctx: CGContext, points: [CGPoint],
                                   fill: UIColor?, inkWidth: CGFloat,
                                   jitter: CGFloat, wobble: inout Wobble,
                                   passes: Int = 2, inkColor: UIColor = ink) {
        if let fill {
            ctx.setFillColor(fill.cgColor)
            ctx.beginPath()
            ctx.addLines(between: points)
            ctx.closePath()
            ctx.fillPath()
        }
        strokeInk(ctx, points: points, width: inkWidth, jitter: jitter,
                  wobble: &wobble, passes: passes, color: inkColor)
    }

    private static func strokeInk(_ ctx: CGContext, points: [CGPoint],
                                  width: CGFloat, jitter: CGFloat,
                                  wobble: inout Wobble, passes: Int = 2,
                                  color: UIColor = ink) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for _ in 0..<passes {
            let jittered = points.map {
                CGPoint(x: $0.x + wobble.spread(jitter), y: $0.y + wobble.spread(jitter))
            }
            ctx.beginPath()
            ctx.addLines(between: jittered)
            ctx.strokePath()
        }
    }

    private static func texture(size: CGSize, seed: UInt64,
                                draw: (CGContext, inout Wobble) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { rc in
            var wobble = Wobble(seed: seed)
            draw(rc.cgContext, &wobble)
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }

    // MARK: - the hero

    /// Side-facing hero (faces right; mirror the node for left).
    static let heroSide: SKTexture = texture(size: CGSize(width: 46, height: 46), seed: 11) { ctx, w in
        // trailing antennae
        for dy in [-4, 4] {
            var pts: [CGPoint] = []
            for i in 0...5 {
                let t = CGFloat(i) / 5
                pts.append(CGPoint(x: 18 - t * 12 + w.spread(1),
                                   y: 10 + CGFloat(dy) * t - t * 4))
            }
            strokeInk(ctx, points: pts, width: 1.6, jitter: 0.5, wobble: &w)
            ctx.setFillColor(bodyGreenDark.cgColor)
            ctx.fillEllipse(in: CGRect(x: pts[5].x - 2.4, y: pts[5].y - 2.4, width: 4.8, height: 4.8))
        }
        // legs trailing below
        strokeInk(ctx, points: [CGPoint(x: 20, y: 34), CGPoint(x: 14, y: 43)],
                  width: 2.6, jitter: 0.6, wobble: &w)
        strokeInk(ctx, points: [CGPoint(x: 28, y: 35), CGPoint(x: 25, y: 44)],
                  width: 2.6, jitter: 0.6, wobble: &w)
        // body: forward-leaning blob
        let body = ellipsePoints(in: CGRect(x: 8, y: 6, width: 34, height: 30))
        fillAndInk(ctx, points: body, fill: bodyGreen, inkWidth: 2.2, jitter: 0.9, wobble: &w)
        // belly shade
        strokeInk(ctx, points: [CGPoint(x: 16, y: 28), CGPoint(x: 34, y: 30)],
                  width: 1.4, jitter: 0.5, wobble: &w, passes: 1, color: bodyGreenDark)
        strokeInk(ctx, points: [CGPoint(x: 18, y: 24), CGPoint(x: 36, y: 26)],
                  width: 1.4, jitter: 0.5, wobble: &w, passes: 1, color: bodyGreenDark)
        // eye looking forward (right)
        let eye = ellipsePoints(in: CGRect(x: 28, y: 10, width: 11, height: 13))
        fillAndInk(ctx, points: eye, fill: .white, inkWidth: 1.6, jitter: 0.5, wobble: &w)
        ctx.setFillColor(ink.cgColor)
        ctx.fillEllipse(in: CGRect(x: 34, y: 15, width: 4, height: 4.6))
        // little determined mouth
        strokeInk(ctx, points: [CGPoint(x: 39, y: 26), CGPoint(x: 43, y: 25)],
                  width: 1.8, jitter: 0.4, wobble: &w)
    }

    /// Face-on hero used while shooting (pellets leave the round mouth).
    static let heroUp: SKTexture = texture(size: CGSize(width: 46, height: 46), seed: 12) { ctx, w in
        for sx in [-1.0, 1.0] {
            var pts: [CGPoint] = []
            for i in 0...5 {
                let t = CGFloat(i) / 5
                pts.append(CGPoint(x: 23 + CGFloat(sx) * (5 + sin(t * 5) * 3),
                                   y: 8 - t * 7))
            }
            strokeInk(ctx, points: pts, width: 1.6, jitter: 0.5, wobble: &w)
            ctx.setFillColor(bodyGreenDark.cgColor)
            ctx.fillEllipse(in: CGRect(x: pts[5].x - 2.2, y: pts[5].y - 2.2, width: 4.4, height: 4.4))
        }
        strokeInk(ctx, points: [CGPoint(x: 16, y: 36), CGPoint(x: 12, y: 44)],
                  width: 2.6, jitter: 0.6, wobble: &w)
        strokeInk(ctx, points: [CGPoint(x: 30, y: 36), CGPoint(x: 34, y: 44)],
                  width: 2.6, jitter: 0.6, wobble: &w)
        let body = ellipsePoints(in: CGRect(x: 6, y: 8, width: 34, height: 30))
        fillAndInk(ctx, points: body, fill: bodyGreen, inkWidth: 2.2, jitter: 0.9, wobble: &w)
        for sx in [-1.0, 1.0] {
            let ex = 23 + CGFloat(sx) * 8
            let eye = ellipsePoints(in: CGRect(x: ex - 5, y: 12, width: 10, height: 12))
            fillAndInk(ctx, points: eye, fill: .white, inkWidth: 1.5, jitter: 0.5, wobble: &w)
            ctx.setFillColor(ink.cgColor)
            ctx.fillEllipse(in: CGRect(x: ex - 2, y: 13.5, width: 4, height: 4.6))
        }
        // round open mouth, aimed at the sky
        let mouth = ellipsePoints(in: CGRect(x: 19, y: 27, width: 9, height: 8))
        fillAndInk(ctx, points: mouth, fill: UIColor(red: 0.45, green: 0.26, blue: 0.18, alpha: 1),
                   inkWidth: 1.5, jitter: 0.4, wobble: &w)
    }

    // MARK: - platforms

    private static func platformTexture(fill: UIColor, seed: UInt64,
                                        cracked: Bool = false,
                                        outline: UIColor = ink) -> SKTexture {
        let size = CGSize(width: Tuning.platformSize.width + 4,
                          height: Tuning.platformSize.height + 4)
        return texture(size: size, seed: seed) { ctx, w in
            let rect = CGRect(x: 2, y: 2, width: Tuning.platformSize.width,
                              height: Tuning.platformSize.height)
            let pts = ellipsePoints(in: rect, steps: 48)
            fillAndInk(ctx, points: pts, fill: fill, inkWidth: 1.8, jitter: 0.8,
                       wobble: &w, inkColor: outline)
            // hatching for volume
            let shade = fill == platformWhite
                ? UIColor(white: 0.82, alpha: 1)
                : fill.darker()
            for i in 0..<5 {
                let x = rect.minX + 8 + CGFloat(i) * 10
                strokeInk(ctx, points: [CGPoint(x: x, y: rect.minY + 3),
                                        CGPoint(x: x - 4, y: rect.maxY - 3)],
                          width: 1.2, jitter: 0.4, wobble: &w, passes: 1, color: shade)
            }
            if cracked {
                var crack: [CGPoint] = []
                var x = rect.midX - 2
                var y = rect.minY + 1
                while y < rect.maxY {
                    crack.append(CGPoint(x: x, y: y))
                    x += w.spread(4)
                    y += 3
                }
                strokeInk(ctx, points: crack, width: 1.4, jitter: 0.3, wobble: &w)
            }
        }
    }

    static let platformGreenTex = platformTexture(fill: platformGreen, seed: 21)
    static let platformBlueTex = platformTexture(fill: platformBlue, seed: 22)
    static let platformBrownTex = platformTexture(fill: platformBrown, seed: 23, cracked: true)
    static let platformBrownCrackedTex = platformTexture(fill: platformBrown, seed: 24, cracked: true)
    static let platformWhiteTex = platformTexture(fill: platformWhite, seed: 25,
                                                  outline: UIColor(white: 0.55, alpha: 1))
    static let platformGrayTex = platformTexture(
        fill: UIColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 1), seed: 28)
    static let platformYellowTex = platformTexture(
        fill: UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1), seed: 29)
    static let platformRedTex = platformTexture(
        fill: UIColor(red: 0.92, green: 0.32, blue: 0.20, alpha: 1), seed: 30)

    /// Draggable platform: dark slate with four little arrows.
    static let platformMovableTex: SKTexture = {
        let size = CGSize(width: Tuning.platformSize.width + 4,
                          height: Tuning.platformSize.height + 4)
        return texture(size: size, seed: 35) { ctx, w in
            let rect = CGRect(x: 2, y: 2, width: Tuning.platformSize.width,
                              height: Tuning.platformSize.height)
            let pts = ellipsePoints(in: rect, steps: 48)
            fillAndInk(ctx, points: pts,
                       fill: UIColor(red: 0.29, green: 0.37, blue: 0.47, alpha: 1),
                       inkWidth: 1.8, jitter: 0.8, wobble: &w)
            // four tiny arrows: up, down, left, right of center
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let white = UIColor(white: 0.95, alpha: 1)
            strokeInk(ctx, points: [CGPoint(x: c.x - 3, y: c.y - 2.5),
                                    CGPoint(x: c.x, y: c.y - 5.5),
                                    CGPoint(x: c.x + 3, y: c.y - 2.5)],
                      width: 1.4, jitter: 0.2, wobble: &w, passes: 1, color: white)
            strokeInk(ctx, points: [CGPoint(x: c.x - 3, y: c.y + 2.5),
                                    CGPoint(x: c.x, y: c.y + 5.5),
                                    CGPoint(x: c.x + 3, y: c.y + 2.5)],
                      width: 1.4, jitter: 0.2, wobble: &w, passes: 1, color: white)
            strokeInk(ctx, points: [CGPoint(x: c.x - 12, y: c.y - 3),
                                    CGPoint(x: c.x - 16, y: c.y),
                                    CGPoint(x: c.x - 12, y: c.y + 3)],
                      width: 1.4, jitter: 0.2, wobble: &w, passes: 1, color: white)
            strokeInk(ctx, points: [CGPoint(x: c.x + 12, y: c.y - 3),
                                    CGPoint(x: c.x + 16, y: c.y),
                                    CGPoint(x: c.x + 12, y: c.y + 3)],
                      width: 1.4, jitter: 0.2, wobble: &w, passes: 1, color: white)
        }
    }()

    /// Two halves of a snapped brown platform, for the crumble animation.
    static func brownFragment(left: Bool) -> SKTexture {
        texture(size: CGSize(width: 32, height: 22), seed: left ? 26 : 27) { ctx, w in
            let pts: [CGPoint]
            if left {
                pts = [CGPoint(x: 2, y: 6), CGPoint(x: 28, y: 2), CGPoint(x: 30, y: 10),
                       CGPoint(x: 24, y: 18), CGPoint(x: 6, y: 16), CGPoint(x: 2, y: 6)]
            } else {
                pts = [CGPoint(x: 2, y: 2), CGPoint(x: 28, y: 6), CGPoint(x: 26, y: 16),
                       CGPoint(x: 8, y: 18), CGPoint(x: 4, y: 10), CGPoint(x: 2, y: 2)]
            }
            fillAndInk(ctx, points: pts, fill: platformBrown, inkWidth: 1.8,
                       jitter: 0.7, wobble: &w)
        }
    }
    static let brownFragmentLeft = brownFragment(left: true)
    static let brownFragmentRight = brownFragment(left: false)

    // MARK: - boost items

    static let springIdle: SKTexture = texture(size: CGSize(width: 20, height: 14), seed: 31) { ctx, w in
        // squat coil with a plate on top
        strokeInk(ctx, points: [CGPoint(x: 4, y: 12), CGPoint(x: 16, y: 10),
                                CGPoint(x: 5, y: 8), CGPoint(x: 15, y: 6)],
                  width: 1.8, jitter: 0.4, wobble: &w)
        let plate = roundedRectPoints(in: CGRect(x: 2, y: 1, width: 16, height: 5), radius: 2)
        fillAndInk(ctx, points: plate, fill: UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1),
                   inkWidth: 1.6, jitter: 0.5, wobble: &w)
    }

    static let springOpen: SKTexture = texture(size: CGSize(width: 20, height: 26), seed: 32) { ctx, w in
        strokeInk(ctx, points: [CGPoint(x: 4, y: 24), CGPoint(x: 16, y: 21),
                                CGPoint(x: 5, y: 18), CGPoint(x: 15, y: 15),
                                CGPoint(x: 5, y: 12), CGPoint(x: 15, y: 9)],
                  width: 1.8, jitter: 0.4, wobble: &w)
        let plate = roundedRectPoints(in: CGRect(x: 2, y: 1, width: 16, height: 5), radius: 2)
        fillAndInk(ctx, points: plate, fill: UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1),
                   inkWidth: 1.6, jitter: 0.5, wobble: &w)
    }

    static let trampolineTex: SKTexture = texture(size: CGSize(width: 36, height: 16), seed: 33) { ctx, w in
        // crossed legs
        strokeInk(ctx, points: [CGPoint(x: 6, y: 4), CGPoint(x: 14, y: 15)],
                  width: 2, jitter: 0.5, wobble: &w)
        strokeInk(ctx, points: [CGPoint(x: 14, y: 4), CGPoint(x: 6, y: 15)],
                  width: 2, jitter: 0.5, wobble: &w)
        strokeInk(ctx, points: [CGPoint(x: 22, y: 4), CGPoint(x: 30, y: 15)],
                  width: 2, jitter: 0.5, wobble: &w)
        strokeInk(ctx, points: [CGPoint(x: 30, y: 4), CGPoint(x: 22, y: 15)],
                  width: 2, jitter: 0.5, wobble: &w)
        // elastic bed
        let bed = roundedRectPoints(in: CGRect(x: 2, y: 1, width: 32, height: 5), radius: 2.5)
        fillAndInk(ctx, points: bed, fill: UIColor(white: 0.20, alpha: 1),
                   inkWidth: 1.6, jitter: 0.5, wobble: &w)
    }

    /// Propeller beanie. `blade` 0...2 selects the spin frame.
    static func propellerHat(blade: Int) -> SKTexture {
        texture(size: CGSize(width: 26, height: 18), seed: 41 + UInt64(blade)) { ctx, w in
            // blade: a bar whose apparent width shrinks as it spins
            let widths: [CGFloat] = [22, 12, 4]
            let bw = widths[blade % 3]
            let blades = roundedRectPoints(in: CGRect(x: 13 - bw / 2, y: 1, width: bw, height: 3), radius: 1.5)
            fillAndInk(ctx, points: blades, fill: UIColor(white: 0.85, alpha: 1),
                       inkWidth: 1.3, jitter: 0.4, wobble: &w)
            strokeInk(ctx, points: [CGPoint(x: 13, y: 4), CGPoint(x: 13, y: 7)],
                      width: 1.6, jitter: 0.3, wobble: &w)
            // cap
            var cap: [CGPoint] = []
            for i in 0...20 {
                let a = .pi - .pi * CGFloat(i) / 20
                cap.append(CGPoint(x: 13 + 10 * cos(a), y: 16 - 9 * sin(a)))
            }
            cap.append(CGPoint(x: 3, y: 16))
            fillAndInk(ctx, points: cap, fill: UIColor(red: 0.90, green: 0.55, blue: 0.15, alpha: 1),
                       inkWidth: 1.6, jitter: 0.5, wobble: &w)
            strokeInk(ctx, points: [CGPoint(x: 8, y: 8.5), CGPoint(x: 7, y: 15)],
                      width: 1.2, jitter: 0.3, wobble: &w, passes: 1)
            strokeInk(ctx, points: [CGPoint(x: 18, y: 8.5), CGPoint(x: 19, y: 15)],
                      width: 1.2, jitter: 0.3, wobble: &w, passes: 1)
        }
    }
    static let propellerFrames = [propellerHat(blade: 0), propellerHat(blade: 1),
                                  propellerHat(blade: 2), propellerHat(blade: 1)]

    /// Jetpack. `flame` -1 for the pickup (no flame), else 0...2.
    static func jetpack(flame: Int) -> SKTexture {
        let h: CGFloat = flame >= 0 ? 42 : 30
        return texture(size: CGSize(width: 22, height: h), seed: 51 + UInt64(flame + 1)) { ctx, w in
            if flame >= 0 {
                let lengths: [CGFloat] = [10, 14, 8]
                let len = lengths[flame % 3]
                let f: [CGPoint] = [CGPoint(x: 7, y: 26), CGPoint(x: 11, y: 26 + len),
                                    CGPoint(x: 15, y: 26)]
                fillAndInk(ctx, points: f, fill: UIColor(red: 0.99, green: 0.62, blue: 0.10, alpha: 1),
                           inkWidth: 1.4, jitter: 0.8, wobble: &w,
                           inkColor: UIColor(red: 0.85, green: 0.25, blue: 0.05, alpha: 1))
            }
            // tank
            let tank = roundedRectPoints(in: CGRect(x: 4, y: 2, width: 14, height: 22), radius: 6)
            fillAndInk(ctx, points: tank, fill: UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1),
                       inkWidth: 1.8, jitter: 0.6, wobble: &w)
            // nozzle
            let nozzle = roundedRectPoints(in: CGRect(x: 7, y: 22, width: 8, height: 5), radius: 1.5)
            fillAndInk(ctx, points: nozzle, fill: UIColor(white: 0.35, alpha: 1),
                       inkWidth: 1.4, jitter: 0.4, wobble: &w)
            // stripe
            strokeInk(ctx, points: [CGPoint(x: 5, y: 12), CGPoint(x: 17, y: 12)],
                      width: 2.2, jitter: 0.3, wobble: &w, passes: 1,
                      color: UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1))
        }
    }
    static let jetpackPickup = jetpack(flame: -1)
    static let jetpackFrames = [jetpack(flame: 0), jetpack(flame: 1), jetpack(flame: 2)]

    /// Spring shoes: a pair of little red boots on coils.
    static let springShoesTex: SKTexture = texture(size: CGSize(width: 26, height: 18), seed: 55) { ctx, w in
        for offset in [CGFloat(0), 13] {
            strokeInk(ctx, points: [CGPoint(x: offset + 3, y: 16), CGPoint(x: offset + 10, y: 14),
                                    CGPoint(x: offset + 4, y: 12)],
                      width: 1.5, jitter: 0.3, wobble: &w)
            let boot = roundedRectPoints(in: CGRect(x: offset + 1, y: 3, width: 11, height: 8), radius: 3)
            fillAndInk(ctx, points: boot, fill: UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1),
                       inkWidth: 1.5, jitter: 0.4, wobble: &w)
        }
    }

    /// Force-shield pickup: a small crackling bubble.
    static let shieldPickupTex: SKTexture = texture(size: CGSize(width: 22, height: 22), seed: 56) { ctx, w in
        let ring = ellipsePoints(in: CGRect(x: 2, y: 2, width: 18, height: 18), steps: 32)
        fillAndInk(ctx, points: ring, fill: UIColor(red: 0.55, green: 0.80, blue: 0.95, alpha: 0.35),
                   inkWidth: 1.6, jitter: 0.6, wobble: &w,
                   inkColor: UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1))
        strokeInk(ctx, points: [CGPoint(x: 7, y: 12), CGPoint(x: 11, y: 8), CGPoint(x: 10, y: 12),
                                CGPoint(x: 14, y: 9)],
                  width: 1.2, jitter: 0.3, wobble: &w,
                  color: UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1))
    }

    /// The worn shield bubble drawn around the hero.
    static let shieldBubbleTex: SKTexture = texture(size: CGSize(width: 60, height: 60), seed: 57) { ctx, w in
        let ring = ellipsePoints(in: CGRect(x: 3, y: 3, width: 54, height: 54), steps: 48)
        fillAndInk(ctx, points: ring, fill: UIColor(red: 0.55, green: 0.80, blue: 0.95, alpha: 0.16),
                   inkWidth: 1.8, jitter: 1.2, wobble: &w,
                   inkColor: UIColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 0.8))
    }

    // MARK: - hazards

    /// Winged blob monster, two wing frames.
    static func monsterWinged(frame: Int) -> SKTexture {
        texture(size: CGSize(width: 56, height: 40), seed: 61 + UInt64(frame)) { ctx, w in
            let wingLift: CGFloat = frame == 0 ? 0 : -7
            for sx in [-1.0, 1.0] {
                let baseX = 28 + CGFloat(sx) * 20
                let wing: [CGPoint] = [
                    CGPoint(x: 28 + CGFloat(sx) * 12, y: 18),
                    CGPoint(x: baseX + CGFloat(sx) * 6, y: 10 + wingLift),
                    CGPoint(x: baseX + CGFloat(sx) * 2, y: 16 + wingLift / 2),
                    CGPoint(x: baseX + CGFloat(sx) * 7, y: 20 + wingLift),
                    CGPoint(x: 28 + CGFloat(sx) * 13, y: 24),
                ]
                fillAndInk(ctx, points: wing, fill: UIColor(red: 0.80, green: 0.72, blue: 0.92, alpha: 1),
                           inkWidth: 1.6, jitter: 0.6, wobble: &w)
            }
            let body = ellipsePoints(in: CGRect(x: 12, y: 8, width: 32, height: 26))
            fillAndInk(ctx, points: body, fill: monsterPurple, inkWidth: 2, jitter: 0.8, wobble: &w)
            // one big cyclops eye
            let eye = ellipsePoints(in: CGRect(x: 22, y: 13, width: 12, height: 13))
            fillAndInk(ctx, points: eye, fill: .white, inkWidth: 1.5, jitter: 0.4, wobble: &w)
            ctx.setFillColor(ink.cgColor)
            ctx.fillEllipse(in: CGRect(x: 26, y: 18, width: 4.4, height: 4.8))
            // grumpy zigzag mouth
            strokeInk(ctx, points: [CGPoint(x: 20, y: 30), CGPoint(x: 24, y: 28),
                                    CGPoint(x: 28, y: 30), CGPoint(x: 32, y: 28),
                                    CGPoint(x: 36, y: 30)],
                      width: 1.5, jitter: 0.3, wobble: &w)
            // stubby horns
            strokeInk(ctx, points: [CGPoint(x: 20, y: 9), CGPoint(x: 17, y: 3)],
                      width: 2.2, jitter: 0.4, wobble: &w)
            strokeInk(ctx, points: [CGPoint(x: 36, y: 9), CGPoint(x: 39, y: 3)],
                      width: 2.2, jitter: 0.4, wobble: &w)
        }
    }
    static let monsterWingedFrames = [monsterWinged(frame: 0), monsterWinged(frame: 1)]

    /// Tall wobbling monster with three stacked eyes.
    static let monsterTall: SKTexture = texture(size: CGSize(width: 40, height: 56), seed: 65) { ctx, w in
        var outline: [CGPoint] = []
        for i in 0...40 {
            let t = CGFloat(i) / 40
            let a = .pi * 2 * t
            let r: CGFloat = 16 + sin(a * 5) * 2.2
            outline.append(CGPoint(x: 20 + r * cos(a) * 0.9, y: 28 + r * sin(a) * 1.6))
        }
        fillAndInk(ctx, points: outline, fill: monsterTeal, inkWidth: 2, jitter: 0.9, wobble: &w)
        for i in 0..<3 {
            let ey = 12 + CGFloat(i) * 13
            let eye = ellipsePoints(in: CGRect(x: 14, y: ey, width: 12, height: 10))
            fillAndInk(ctx, points: eye, fill: .white, inkWidth: 1.4, jitter: 0.4, wobble: &w)
            ctx.setFillColor(ink.cgColor)
            ctx.fillEllipse(in: CGRect(x: 18.5, y: ey + 3, width: 3.6, height: 4))
        }
    }

    /// Wide flier that patrols the whole screen: a flat red zeppelin-bug
    /// with one long fin, two flap frames.
    static func monsterFlier(frame: Int) -> SKTexture {
        texture(size: CGSize(width: 62, height: 30), seed: 67 + UInt64(frame)) { ctx, w in
            let finLift: CGFloat = frame == 0 ? 0 : -6
            let fin: [CGPoint] = [CGPoint(x: 30, y: 10), CGPoint(x: 22, y: 2 + finLift),
                                  CGPoint(x: 40, y: 2 + finLift), CGPoint(x: 34, y: 10)]
            fillAndInk(ctx, points: fin, fill: UIColor(red: 0.95, green: 0.65, blue: 0.60, alpha: 1),
                       inkWidth: 1.5, jitter: 0.5, wobble: &w)
            let body = ellipsePoints(in: CGRect(x: 4, y: 8, width: 54, height: 18))
            fillAndInk(ctx, points: body, fill: UIColor(red: 0.85, green: 0.32, blue: 0.28, alpha: 1),
                       inkWidth: 1.8, jitter: 0.7, wobble: &w)
            for i in 0..<2 {
                let ex = 18 + CGFloat(i) * 18
                let eye = ellipsePoints(in: CGRect(x: ex, y: 11, width: 9, height: 9), steps: 20)
                fillAndInk(ctx, points: eye, fill: .white, inkWidth: 1.3, jitter: 0.3, wobble: &w)
                ctx.setFillColor(ink.cgColor)
                ctx.fillEllipse(in: CGRect(x: ex + 3, y: 14, width: 3.2, height: 3.4))
            }
            // trailing stinger
            strokeInk(ctx, points: [CGPoint(x: 57, y: 17), CGPoint(x: 61, y: 15)],
                      width: 1.8, jitter: 0.3, wobble: &w)
        }
    }
    static let monsterFlierFrames = [monsterFlier(frame: 0), monsterFlier(frame: 1)]

    static let ufoTex: SKTexture = texture(size: CGSize(width: 64, height: 36), seed: 71) { ctx, w in
        // dome
        var dome: [CGPoint] = []
        for i in 0...20 {
            let a = .pi - .pi * CGFloat(i) / 20
            dome.append(CGPoint(x: 32 + 14 * cos(a), y: 16 - 13 * sin(a)))
        }
        fillAndInk(ctx, points: dome, fill: UIColor(red: 0.62, green: 0.85, blue: 0.90, alpha: 0.9),
                   inkWidth: 1.6, jitter: 0.5, wobble: &w)
        // saucer body
        let body = ellipsePoints(in: CGRect(x: 2, y: 12, width: 60, height: 16))
        fillAndInk(ctx, points: body, fill: UIColor(red: 0.66, green: 0.70, blue: 0.76, alpha: 1),
                   inkWidth: 2, jitter: 0.7, wobble: &w)
        // running lights
        for i in 0..<4 {
            let x = 12 + CGFloat(i) * 13
            ctx.setFillColor(UIColor(red: 0.98, green: 0.83, blue: 0.20, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: 18, width: 5, height: 5))
            let ring = ellipsePoints(in: CGRect(x: x, y: 18, width: 5, height: 5), steps: 16)
            strokeInk(ctx, points: ring, width: 1, jitter: 0.3, wobble: &w, passes: 1)
        }
        // little bulb underneath
        let bulb = ellipsePoints(in: CGRect(x: 26, y: 26, width: 12, height: 8))
        fillAndInk(ctx, points: bulb, fill: UIColor(red: 0.98, green: 0.83, blue: 0.20, alpha: 1),
                   inkWidth: 1.4, jitter: 0.4, wobble: &w)
    }

    static let blackHoleTex: SKTexture = texture(size: CGSize(width: 96, height: 96), seed: 75) { ctx, w in
        // hand-scribbled spiral collapsing to a dark core
        ctx.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: 14, y: 14, width: 68, height: 68))
        var spiral: [CGPoint] = []
        let turns: CGFloat = 3.2
        for i in 0...130 {
            let t = CGFloat(i) / 130
            let a = turns * 2 * .pi * t
            let r = 46 * (1 - t * 0.93)
            spiral.append(CGPoint(x: 48 + r * cos(a), y: 48 + r * sin(a)))
        }
        strokeInk(ctx, points: spiral, width: 2.6, jitter: 1.0, wobble: &w,
                  passes: 1, color: UIColor(red: 0.45, green: 0.35, blue: 0.60, alpha: 1))
        strokeInk(ctx, points: spiral, width: 1.4, jitter: 1.8, wobble: &w,
                  passes: 1, color: UIColor(white: 0.75, alpha: 0.8))
        let rim = ellipsePoints(in: CGRect(x: 14, y: 14, width: 68, height: 68), steps: 56)
        strokeInk(ctx, points: rim, width: 2.4, jitter: 1.4, wobble: &w)
    }

    static let pelletTex: SKTexture = texture(size: CGSize(width: 10, height: 10), seed: 81) { ctx, w in
        let ball = ellipsePoints(in: CGRect(x: 1.5, y: 1.5, width: 7, height: 7), steps: 20)
        fillAndInk(ctx, points: ball, fill: UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1),
                   inkWidth: 1.3, jitter: 0.3, wobble: &w)
    }

    // MARK: - environment & chrome

    /// One screen-height strip of graph paper; tiles vertically.
    static func backgroundTile(size: CGSize) -> SKTexture {
        texture(size: size, seed: 91) { ctx, _ in
            ctx.setFillColor(paper.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setStrokeColor(gridBlue.cgColor)
            ctx.setLineWidth(0.7)
            let cell: CGFloat = 32
            var x: CGFloat = 0
            while x <= size.width + 1 {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: size.height))
                x += cell
            }
            var y: CGFloat = 0
            while y <= size.height + 1 {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: size.width, y: y))
                y += cell
            }
            ctx.strokePath()
        }
    }

    /// Torn-paper strip behind the score readout, manila-toned.
    static func hudStrip(width: CGFloat) -> SKTexture {
        texture(size: CGSize(width: width, height: 34), seed: 95) { ctx, w in
            ctx.setFillColor(UIColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 0.94).cgColor)
            var edge: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: width, y: 0)]
            var x = width
            while x > 0 {
                edge.append(CGPoint(x: x, y: 27 + w.spread(4)))
                x -= 14
            }
            edge.append(CGPoint(x: 0, y: 27))
            ctx.beginPath()
            ctx.addLines(between: edge)
            ctx.closePath()
            ctx.fillPath()
            // soft shadow line under the tear
            strokeInk(ctx, points: Array(edge.dropFirst(2)), width: 1.2, jitter: 0.5,
                      wobble: &w, passes: 1, color: UIColor(white: 0.6, alpha: 0.5))
        }
    }

    /// Wobbly-outline button plate.
    static func buttonPlate(size: CGSize, seed: UInt64 = 101) -> SKTexture {
        texture(size: CGSize(width: size.width + 8, height: size.height + 8), seed: seed) { ctx, w in
            let rect = CGRect(x: 4, y: 4, width: size.width, height: size.height)
            let pts = roundedRectPoints(in: rect, radius: min(14, size.height / 2))
            fillAndInk(ctx, points: pts, fill: UIColor(red: 0.99, green: 0.97, blue: 0.90, alpha: 0.96),
                       inkWidth: 2.2, jitter: 1.1, wobble: &w)
        }
    }

    /// Big torn-paper panel for the game-over card.
    static func tornPanel(size: CGSize) -> SKTexture {
        texture(size: size, seed: 105) { ctx, w in
            var pts: [CGPoint] = []
            func tornEdge(from a: CGPoint, to b: CGPoint, steps: Int) {
                for i in 0..<steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    pts.append(CGPoint(x: a.x + (b.x - a.x) * t + w.spread(3),
                                       y: a.y + (b.y - a.y) * t + w.spread(3)))
                }
            }
            let inset: CGFloat = 6
            tornEdge(from: CGPoint(x: inset, y: inset), to: CGPoint(x: size.width - inset, y: inset), steps: 14)
            tornEdge(from: CGPoint(x: size.width - inset, y: inset),
                     to: CGPoint(x: size.width - inset, y: size.height - inset), steps: 18)
            tornEdge(from: CGPoint(x: size.width - inset, y: size.height - inset),
                     to: CGPoint(x: inset, y: size.height - inset), steps: 14)
            tornEdge(from: CGPoint(x: inset, y: size.height - inset), to: CGPoint(x: inset, y: inset), steps: 18)
            pts.append(pts[0])
            ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 5,
                          color: UIColor(white: 0, alpha: 0.35).cgColor)
            fillAndInk(ctx, points: pts, fill: UIColor(red: 0.99, green: 0.97, blue: 0.90, alpha: 1),
                       inkWidth: 1.6, jitter: 0.6, wobble: &w,
                       inkColor: UIColor(white: 0.55, alpha: 0.8))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            // faint grid on the panel too
            ctx.setStrokeColor(gridBlue.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(0.6)
            var gx: CGFloat = 10
            while gx < size.width - 10 {
                ctx.move(to: CGPoint(x: gx, y: 10))
                ctx.addLine(to: CGPoint(x: gx, y: size.height - 10))
                gx += 32
            }
            var gy: CGFloat = 10
            while gy < size.height - 10 {
                ctx.move(to: CGPoint(x: 10, y: gy))
                ctx.addLine(to: CGPoint(x: size.width - 10, y: gy))
                gy += 32
            }
            ctx.strokePath()
        }
    }
}

private extension UIColor {
    func darker(by factor: CGFloat = 0.72) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }
}
