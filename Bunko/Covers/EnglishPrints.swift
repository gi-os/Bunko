import SwiftUI

/// Marbled paper: bands of colour floated and combed, each lying over the last, with dark veins
/// where they meet. Seeded, so a book's sheet is always its own.
struct Marbling: View {
    let seed: String
    let colours: [Color]
    var bands = 26

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(string: seed + "marble")
            // Floated in thin bands, then combed: a fine zigzag over a slow swell.
            let count = bands * 3
            let step = size.height / CGFloat(count) * 1.1
            let f1 = CGFloat.random(in: 1.5...3.0, using: &rng) * .pi / size.width
            let f2 = CGFloat.random(in: 5.0...8.0, using: &rng) * .pi / size.width
            let comb = CGFloat.random(in: 34.0...48.0, using: &rng) * .pi / size.width
            for k in -4..<(count + 4) {
                let base = CGFloat(k) * step
                let a1 = step * .random(in: 2.5...4.0, using: &rng), a2 = step * .random(in: 0.4...1.0, using: &rng)
                let p1 = CGFloat.random(in: 0..<(.pi * 2), using: &rng), p2 = CGFloat.random(in: 0..<(.pi * 2), using: &rng)
                var edge = Path()
                var x: CGFloat = 0
                edge.move(to: CGPoint(x: 0, y: base))
                while x <= size.width + 4 {
                    let swell = a1 * sin(x * f1 + p1 + base / size.height * 2.5)
                    let y = base + swell + a2 * sin(x * f2 + p2) + step * 0.55 * sin(x * comb + CGFloat(k) * 0.3)
                    edge.addLine(to: CGPoint(x: x, y: y))
                    x += 3
                }
                var below = edge
                below.addLine(to: CGPoint(x: size.width + 4, y: size.height + step * 4))
                below.addLine(to: CGPoint(x: 0, y: size.height + step * 4))
                below.closeSubpath()
                let colour = colours[Int.random(in: 0..<colours.count, using: &rng)]
                ctx.fill(below, with: .color(colour))
                ctx.stroke(edge, with: .color(Color(hex: "2A1E16").opacity(.random(in: 0.15...0.45, using: &rng))),
                           lineWidth: .random(in: 0.3...0.8, using: &rng))
            }
        }
    }
}

/// A linocut landscape: the sun and the hills left standing, the rest cut away in gouge strokes.
struct LinoLandscape: View {
    let paper: Color
    let seed: String

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(string: seed + "lino")
            let w = size.width, h = size.height
            // The sky, cut in short horizontal strokes.
            for _ in 0..<Int(w * h / 900) {
                let y = CGFloat.random(in: 0..<(h * 0.55), using: &rng), x = CGFloat.random(in: 0..<w, using: &rng)
                var cut = Path()
                cut.move(to: CGPoint(x: x, y: y))
                cut.addQuadCurve(to: CGPoint(x: x + .random(in: 8...26, using: &rng), y: y + .random(in: -1...1, using: &rng)),
                                 control: CGPoint(x: x + 6, y: y - 1.5))
                ctx.stroke(cut, with: .color(paper), style: StrokeStyle(lineWidth: .random(in: 0.8...1.8, using: &rng), lineCap: .round))
            }
            // The sun, cut round.
            let r = w * 0.13
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.68 - r, y: h * 0.24 - r, width: r * 2, height: r * 2)), with: .color(paper))
            // Hills, their contours cut.
            for k in 0..<3 {
                let top = h * (0.52 + CGFloat(k) * 0.13)
                var contour = Path()
                contour.move(to: CGPoint(x: 0, y: top))
                var x: CGFloat = 0
                let phase = CGFloat.random(in: 0..<6, using: &rng)
                while x <= w {
                    contour.addLine(to: CGPoint(x: x, y: top + h * 0.05 * sin(x / w * 4 + phase)))
                    x += 4
                }
                ctx.stroke(contour, with: .color(paper), style: StrokeStyle(lineWidth: max(1, w * 0.012), lineCap: .round))
                ctx.stroke(contour.offsetBy(dx: 0, dy: h * 0.03), with: .color(paper), style: StrokeStyle(lineWidth: max(0.6, w * 0.005), lineCap: .round))
            }
        }
    }
}

/// A linocut moon: a disc cut out of the block, rings of gouge left in it.
struct LinoMoon: View {
    let paper: Color
    let ink: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width * 0.5, y: size.height * 0.46)
            let r = min(size.width, size.height) * 0.34
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(paper))
            for k in 1..<6 {
                let rr = r * CGFloat(k) / 6
                var ring = Path()
                ring.addArc(center: c, radius: rr, startAngle: .degrees(Double(20 * k)), endAngle: .degrees(Double(20 * k) + 250), clockwise: false)
                // Ridges left standing in the cut-away disc print in the ink.
                ctx.stroke(ring, with: .color(ink), style: StrokeStyle(lineWidth: max(0.8, r * 0.025), lineCap: .round))
            }
            // Radiating cuts round the disc.
            for i in 0..<28 {
                let a = CGFloat(i) / 28 * 2 * .pi
                var ray = Path()
                ray.move(to: CGPoint(x: c.x + cos(a) * r * 1.12, y: c.y + sin(a) * r * 1.12))
                ray.addLine(to: CGPoint(x: c.x + cos(a) * r * 1.35, y: c.y + sin(a) * r * 1.35))
                ctx.stroke(ray, with: .color(paper), style: StrokeStyle(lineWidth: max(0.8, r * 0.03), lineCap: .round))
            }
        }
    }
}

/// A linocut sea: rows of waves cut into the block.
struct LinoWaves: View {
    let paper: Color
    let seed: String

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(string: seed + "waves")
            let rowStep = size.height / 9
            var y = rowStep * 0.5
            while y < size.height {
                var wave = Path()
                var x: CGFloat = -10
                let phase = CGFloat.random(in: 0..<6, using: &rng)
                wave.move(to: CGPoint(x: x, y: y))
                while x <= size.width + 10 {
                    wave.addLine(to: CGPoint(x: x, y: y + rowStep * 0.22 * sin(x / size.width * 9 + phase)))
                    x += 3
                }
                ctx.stroke(wave, with: .color(paper), style: StrokeStyle(lineWidth: max(1, size.width * 0.014), lineCap: .round))
                y += rowStep
            }
        }
    }
}

/// A wood-engraved night: the sky in fine horizontal lines, heavier towards the top, the moon
/// left white, the sea in closer lines below.
struct EngravedVignette: View {
    let ink: Color
    var moonAt: CGFloat = 0.5

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let moon = CGPoint(x: w * moonAt, y: h * 0.36), r = w * 0.12
            let horizon = h * 0.62
            var y: CGFloat = 1
            while y < h {
                let sea = y > horizon
                let weight = sea ? 0.45 + 0.5 * (y - horizon) / (h - horizon) : 1.1 - 0.75 * y / horizon
                var line = Path()
                if !sea, abs(y - moon.y) < r {
                    let half = sqrt(r * r - (y - moon.y) * (y - moon.y))
                    line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: moon.x - half, y: y))
                    line.move(to: CGPoint(x: moon.x + half, y: y)); line.addLine(to: CGPoint(x: w, y: y))
                } else if sea {
                    // The moon's path on the water: short breaks in the lines, scattered and narrowing.
                    let depth = (y - horizon) / (h - horizon)
                    let wobble = sin(y * 1.7) * r * 0.35 * depth
                    let gap = r * (0.55 - 0.35 * depth) * (0.6 + 0.4 * abs(sin(y * 3.1)))
                    line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: moon.x + wobble - gap, y: y))
                    line.move(to: CGPoint(x: moon.x + wobble + gap, y: y)); line.addLine(to: CGPoint(x: w, y: y))
                } else {
                    line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: w, y: y))
                }
                ctx.stroke(line, with: .color(ink), lineWidth: max(0.3, weight * w * 0.006))
                y += sea ? w * 0.016 : w * 0.02
            }
        }
    }
}

/// An engraver's border: fine double lines, hatched between, crossed at the corners.
struct EngravedBorder: View {
    let ink: Color
    let inset: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let band = size.width * 0.05
            let inner = outer.insetBy(dx: band, dy: band)
            ctx.stroke(Path(outer), with: .color(ink), lineWidth: max(0.6, size.width * 0.005))
            ctx.stroke(Path(inner), with: .color(ink), lineWidth: max(0.4, size.width * 0.003))
            var hatch = Path()
            var t: CGFloat = -size.height
            while t < size.width + size.height {
                hatch.move(to: CGPoint(x: t, y: 0)); hatch.addLine(to: CGPoint(x: t + size.height, y: size.height))
                t += size.width * 0.012
            }
            var frame = Path(outer)
            frame.addRect(inner)
            var clipped = ctx
            clipped.clip(to: frame, style: FillStyle(eoFill: true))
            clipped.stroke(hatch, with: .color(ink.opacity(0.6)), lineWidth: 0.4)
            for corner in [outer.origin, CGPoint(x: inner.maxX, y: outer.minY), CGPoint(x: outer.minX, y: inner.maxY), CGPoint(x: inner.maxX, y: inner.maxY)] {
                let square = CGRect(origin: corner, size: CGSize(width: band, height: band))
                clipped.fill(Path(square), with: .color(ink.opacity(0.85)))
            }
        }
    }
}

/// Guilloché: the engine-turned rosette of a banknote, rings of looping lines.
struct Guilloche: View {
    let ink: Color
    let accent: Color
    var loops = 9

    var body: some View {
        Canvas { ctx, size in
            let rings: [(CGFloat, Color)] = [(0.95, ink), (0.7, accent), (0.48, ink)]
            for (ring, colour) in rings {
                ctx.stroke(rosette(in: size, ring: ring), with: .color(colour), lineWidth: max(0.45, min(size.width, size.height) * 0.0055))
            }
        }
    }

    /// A hypotrochoid: a point on a wheel rolling inside a ring.
    private func rosette(in size: CGSize, ring: CGFloat) -> Path {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let big: CGFloat = min(size.width, size.height) / 2 * ring
        let small: CGFloat = big / CGFloat(loops)
        let arm: CGFloat = small * 1.9
        let turn: CGFloat = (big - small) / small
        var path = Path()
        let steps = 900
        for i in 0...steps {
            let t: CGFloat = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let x: CGFloat = (big - small) * cos(t) + arm * cos(turn * t)
            let y: CGFloat = (big - small) * sin(t) - arm * sin(turn * t)
            let point = CGPoint(x: centre.x + x * 0.9, y: centre.y + y * 0.9)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A halftone screen: dots on a grid turned to `angle`, each sized by `coverage` (0...1) there.
struct Halftone: View {
    let ink: Color
    var angle: Double = 45
    let pitch: CGFloat
    let coverage: (CGPoint, CGSize) -> CGFloat

    var body: some View {
        Canvas { ctx, size in
            let a = CGFloat(angle) * .pi / 180, c = cos(a), s = sin(a)
            let p = max(2, pitch)
            let reach = hypot(size.width, size.height)
            var dots = Path()
            var i = -reach
            while i < reach {
                var j = -reach
                while j < reach {
                    let point = CGPoint(x: size.width / 2 + i * c - j * s, y: size.height / 2 + i * s + j * c)
                    if point.x > -p, point.y > -p, point.x < size.width + p, point.y < size.height + p {
                        let k = min(1, max(0, coverage(point, size)))
                        if k > 0.02 {
                            let r = p * 0.62 * sqrt(k)
                            dots.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                        }
                    }
                    j += p
                }
                i += p
            }
            ctx.fill(dots, with: .color(ink))
        }
    }
}

/// Concentric half rings, opening downward.
struct Arcs: Shape {
    var count = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for k in 1...count {
            let r = min(rect.width, rect.height) / 2 * CGFloat(k) / CGFloat(count)
            path.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.move(to: CGPoint(x: c.x - r - 1, y: c.y))
        }
        return path
    }
}

/// Wedges of light from a point at the foot.
struct Rays: Shape {
    var count = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: rect.midX, y: rect.maxY)
        let reach = hypot(rect.width, rect.height)
        for i in 0..<count {
            let a0 = CGFloat.pi + CGFloat(i * 2) / CGFloat(count * 2) * .pi
            let a1 = a0 + .pi / CGFloat(count * 2)
            path.move(to: origin)
            path.addLine(to: CGPoint(x: origin.x + cos(a0) * reach, y: origin.y + sin(a0) * reach))
            path.addLine(to: CGPoint(x: origin.x + cos(a1) * reach, y: origin.y + sin(a1) * reach))
            path.closeSubpath()
        }
        return path
    }
}

/// Half a rectangle, cut corner to corner.
struct SplitDiagonal: Shape {
    var rising = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if rising {
            path.addLines([CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY)])
        } else {
            path.addLines([CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)])
        }
        path.closeSubpath()
        return path
    }
}

/// Lines fanned out from the foot, the art deco sunburst.
struct Sunburst: Shape {
    var lines = 36

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.05)
        for i in 0...lines {
            let a = CGFloat.pi + CGFloat(i) / CGFloat(lines) * .pi
            path.move(to: CGPoint(x: origin.x + cos(a) * rect.width * 0.18, y: origin.y + sin(a) * rect.width * 0.18))
            path.addLine(to: CGPoint(x: origin.x + cos(a) * rect.height * 1.3, y: origin.y + sin(a) * rect.height * 1.3))
        }
        return path
    }
}

/// A stepped skyline, narrower as it rises.
struct Ziggurat: Shape {
    var steps = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for k in 0..<steps {
            let width = rect.width * (1 - CGFloat(k) / CGFloat(steps) * 0.85)
            let height = rect.height / CGFloat(steps)
            let y = rect.maxY - height * CGFloat(k + 1)
            path.addRect(CGRect(x: rect.midX - width / 2, y: y + height * 0.12, width: width, height: height * 0.76))
        }
        return path
    }
}

/// A fan of half rings rising from the foot.
struct Fan: Shape {
    var rings = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.maxY)
        for k in 1...rings {
            let r = rect.width / 2 * CGFloat(k) / CGFloat(rings)
            path.move(to: CGPoint(x: c.x - r, y: c.y))
            path.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }
        for i in 1..<8 {
            let a = CGFloat.pi + CGFloat(i) / 8 * .pi
            path.move(to: c)
            path.addLine(to: CGPoint(x: c.x + cos(a) * rect.width / 2, y: c.y + sin(a) * rect.width / 2))
        }
        return path
    }
}

/// Three chevrons, nested.
struct Chevrons: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for k in 0..<3 {
            let y = rect.minY + rect.height * CGFloat(k) / 3
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.midX, y: y + rect.height / 3))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// Paper with a deckle: its fore-edge left as it came from the mould, not quite straight.
struct Deckle: Shape {
    var seed: String
    var foreEdgeRight = true

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(string: seed + "deckle")
        var path = Path()
        let depth = max(2, rect.width * 0.012)
        let edgeX = foreEdgeRight ? rect.maxX : rect.minX
        let inward: CGFloat = foreEdgeRight ? -1 : 1
        path.move(to: CGPoint(x: foreEdgeRight ? rect.minX : rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: edgeX, y: rect.minY))
        var y = rect.minY
        while y < rect.maxY {
            y = min(rect.maxY, y + .random(in: 2...6, using: &rng))
            path.addLine(to: CGPoint(x: edgeX + inward * .random(in: 0...depth, using: &rng), y: y))
        }
        path.addLine(to: CGPoint(x: foreEdgeRight ? rect.minX : rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
