import SwiftUI

/// The English bookshops' papers, printed on the roll: stripes and checks from shirting and
/// awnings, stationery (graph, ledger, music, laid, airmail), printed repeats (fleur-de-lis,
/// damask, sprigs, stars), maps, a crossword, marbling and tissue. Everything is sized to the
/// cover's width (`w`), so a spine or a thumbnail cut from the same paper shows the same print.
enum EnglishPapers {
    static func draw(_ paper: CoverStyle.Paper, in ctx: inout GraphicsContext, size: CGSize, w: CGFloat,
                     base: Color, ink: Color, seed: String) {
        switch paper {
        case .brownpaper: words(&ctx, size: size, w: w, ink: ink.opacity(0.32))
        case .ticking: stripes(&ctx, size: size, period: w * 0.16, bands: [(0, w * 0.014), (w * 0.03, w * 0.004), (w * 0.046, w * 0.004)], ink: ink.opacity(0.85))
        case .pinstripe: stripes(&ctx, size: size, period: w * 0.05, bands: [(0, max(0.5, w * 0.003))], ink: ink.opacity(0.55))
        case .awning: stripes(&ctx, size: size, period: w * 0.18, bands: [(0, w * 0.09)], ink: ink)
        case .gingham: check(&ctx, size: size, period: w * 0.1, band: w * 0.05, ink: ink.opacity(0.32))
        case .tartan: tartan(&ctx, size: size, w: w, ink: ink)
        case .houndstooth: houndstooth(&ctx, size: size, cell: w * 0.06, ink: ink)
        case .polka: dots(&ctx, size: size, spacing: w * 0.1, radius: w * 0.022, ink: ink)
        case .harlequin: harlequin(&ctx, size: size, w: w, ink: ink)
        case .herringbone: herringbone(&ctx, size: size, w: w, ink: ink.opacity(0.4))
        case .chevron: chevron(&ctx, size: size, w: w, ink: ink.opacity(0.85))
        case .graph: graph(&ctx, size: size, w: w, ink: ink)
        case .ledger: ledger(&ctx, size: size, w: w, ink: ink)
        case .music: music(&ctx, size: size, w: w, ink: ink.opacity(0.55))
        case .fleur: glyphs(&ctx, size: size, glyph: "⚜", spacing: w * 0.13, glyphSize: w * 0.075, inks: [ink])
        case .damask:
            glyphs(&ctx, size: size, glyph: "❦", spacing: w * 0.24, glyphSize: w * 0.17, inks: [ink])
            glyphs(&ctx, size: size, glyph: "✦", spacing: w * 0.24, glyphSize: w * 0.05, inks: [ink], offset: CGPoint(x: w * 0.12, y: w * 0.1))
        case .sprig: glyphs(&ctx, size: size, glyph: "✿", spacing: w * 0.11, glyphSize: w * 0.05, inks: [ink, Color(hex: "C9707E")], jitter: w * 0.02, seed: seed)
        case .stars: scatter(&ctx, size: size, glyph: "✶", count: Int(size.width * size.height / (w * w) * 60), sizes: w * 0.02...w * 0.05, ink: ink, seed: seed)
        case .scales: scales(&ctx, size: size, r: w * 0.06, ink: ink.opacity(0.55))
        case .ripple: ripple(&ctx, size: size, w: w, ink: ink.opacity(0.4))
        case .ordnance: ordnance(&ctx, size: size, w: w, ink: ink, seed: seed)
        case .crossword: crossword(&ctx, size: size, w: w, ink: ink, seed: seed)
        case .marbledpaper:
            Marbling.draw(&ctx, size: size, seed: seed,
                          colours: [base, ink, Color(hex: "C9A15A"), Color(hex: "2F4F7F"), Color(hex: "E9DCC4")], bands: 22)
        case .trellis: trellis(&ctx, size: size, w: w, ink: ink)
        case .quatrefoil: quatrefoil(&ctx, size: size, w: w, ink: ink.opacity(0.7))
        case .argyle: argyle(&ctx, size: size, w: w, ink: ink)
        case .tissue: creases(&ctx, size: size, seed: seed)
        case .laid: laid(&ctx, size: size, w: w, ink: ink)
        case .airmail: airmail(&ctx, size: size, w: w)
        case .windowpane: check(&ctx, size: size, period: w * 0.2, band: max(0.6, w * 0.005), ink: ink.opacity(0.7))
        default: break
        }
    }

    // MARK: Stripes and checks

    static func stripes(_ ctx: inout GraphicsContext, size: CGSize, period: CGFloat, bands: [(CGFloat, CGFloat)], ink: Color) {
        var path = Path()
        var x: CGFloat = 0
        while x < size.width {
            for (offset, width) in bands { path.addRect(CGRect(x: x + offset, y: 0, width: width, height: size.height)) }
            x += period
        }
        ctx.fill(path, with: .color(ink))
    }

    static func check(_ ctx: inout GraphicsContext, size: CGSize, period: CGFloat, band: CGFloat, ink: Color) {
        var across = Path(), down = Path()
        var t: CGFloat = 0
        while t < max(size.width, size.height) {
            down.addRect(CGRect(x: t, y: 0, width: band, height: size.height))
            across.addRect(CGRect(x: 0, y: t, width: size.width, height: band))
            t += period
        }
        // Where the threads cross the colour doubles, as in woven gingham.
        ctx.fill(down, with: .color(ink))
        ctx.fill(across, with: .color(ink))
    }

    static func tartan(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        check(&ctx, size: size, period: w * 0.26, band: w * 0.09, ink: Color.black.opacity(0.28))
        var red = Path(), gold = Path()
        var t: CGFloat = w * 0.04
        while t < max(size.width, size.height) {
            red.addRect(CGRect(x: t, y: 0, width: w * 0.02, height: size.height))
            red.addRect(CGRect(x: 0, y: t, width: size.width, height: w * 0.02))
            gold.addRect(CGRect(x: t + w * 0.13, y: 0, width: max(0.6, w * 0.005), height: size.height))
            gold.addRect(CGRect(x: 0, y: t + w * 0.13, width: size.width, height: max(0.6, w * 0.005)))
            t += w * 0.26
        }
        ctx.fill(red, with: .color(ink.opacity(0.85)))
        ctx.fill(gold, with: .color(Color(hex: "D9B65A")))
    }

    static func houndstooth(_ ctx: inout GraphicsContext, size: CGSize, cell s: CGFloat, ink: Color) {
        var path = Path()
        var j = 0
        var y: CGFloat = -s
        while y < size.height + s {
            var i = 0
            var x: CGFloat = -s
            while x < size.width + s {
                if (i + j).isMultiple(of: 2) {
                    // A square, and its tooth biting up and to the right.
                    path.addRect(CGRect(x: x, y: y, width: s / 2, height: s / 2))
                    path.addLines([CGPoint(x: x + s / 2, y: y), CGPoint(x: x + s, y: y - s / 2), CGPoint(x: x + s, y: y), CGPoint(x: x + s / 2, y: y + s / 2)])
                    path.closeSubpath()
                    path.addLines([CGPoint(x: x, y: y + s / 2), CGPoint(x: x + s / 2, y: y + s / 2), CGPoint(x: x, y: y + s)])
                    path.closeSubpath()
                }
                x += s / 2
                i += 1
            }
            y += s / 2
            j += 1
        }
        ctx.fill(path, with: .color(ink))
    }

    static func dots(_ ctx: inout GraphicsContext, size: CGSize, spacing: CGFloat, radius: CGFloat, ink: Color) {
        var path = Path()
        var row = 0
        var y = spacing / 2
        while y < size.height + spacing {
            var x = row.isMultiple(of: 2) ? spacing / 2 : 0
            while x < size.width + spacing {
                path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += spacing
            }
            y += spacing * 0.5
            row += 1
        }
        ctx.fill(path, with: .color(ink))
    }

    static func harlequin(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let dw = w * 0.16, dh = w * 0.24
        var filled = Path(), lines = Path()
        var j = 0
        var y: CGFloat = -dh
        while y < size.height + dh {
            var i = 0
            var x: CGFloat = (j.isMultiple(of: 2) ? 0 : dw / 2) - dw
            while x < size.width + dw {
                var diamond = Path()
                diamond.addLines([CGPoint(x: x + dw / 2, y: y), CGPoint(x: x + dw, y: y + dh / 2), CGPoint(x: x + dw / 2, y: y + dh), CGPoint(x: x, y: y + dh / 2)])
                diamond.closeSubpath()
                if i.isMultiple(of: 2) { filled.addPath(diamond) }
                lines.addPath(diamond)
                x += dw
                i += 1
            }
            y += dh / 2
            j += 1
        }
        ctx.fill(filled, with: .color(ink.opacity(0.55)))
        ctx.stroke(lines, with: .color(ink.opacity(0.8)), lineWidth: max(0.5, w * 0.003))
    }

    static func herringbone(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let column = w * 0.06, step = w * 0.018
        var path = Path()
        var c = 0
        var x: CGFloat = 0
        while x < size.width {
            var y: CGFloat = -column
            while y < size.height + column {
                let rise = c.isMultiple(of: 2) ? column : -column
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + column, y: y + rise * 0.6))
                y += step
            }
            x += column
            c += 1
        }
        ctx.stroke(path, with: .color(ink), lineWidth: max(0.5, w * 0.005))
    }

    static func chevron(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let period = w * 0.1, amplitude = w * 0.04
        var path = Path()
        var y: CGFloat = -amplitude
        while y < size.height + period {
            var x: CGFloat = 0
            path.move(to: CGPoint(x: 0, y: y))
            var up = true
            while x < size.width + period {
                x += period / 2
                path.addLine(to: CGPoint(x: x, y: y + (up ? -amplitude : 0)))
                up.toggle()
            }
            y += period
        }
        ctx.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: w * 0.028, lineJoin: .miter))
    }

    // MARK: Stationery

    static func graph(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let cell = w * 0.025
        var fine = Path(), bold = Path()
        var k = 0
        var t: CGFloat = 0
        while t < max(size.width, size.height) {
            var line = Path()
            line.move(to: CGPoint(x: t, y: 0)); line.addLine(to: CGPoint(x: t, y: size.height))
            line.move(to: CGPoint(x: 0, y: t)); line.addLine(to: CGPoint(x: size.width, y: t))
            if k.isMultiple(of: 5) { bold.addPath(line) } else { fine.addPath(line) }
            t += cell
            k += 1
        }
        ctx.stroke(fine, with: .color(ink.opacity(0.35)), lineWidth: 0.4)
        ctx.stroke(bold, with: .color(ink.opacity(0.7)), lineWidth: max(0.5, w * 0.003))
    }

    static func ledger(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        var lines = Path()
        var y = w * 0.12
        while y < size.height {
            lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
            y += w * 0.045
        }
        ctx.stroke(lines, with: .color(ink.opacity(0.45)), lineWidth: max(0.4, w * 0.002))
        for x in [w * 0.12, w * 0.135] {
            ctx.fill(Path(CGRect(x: x, y: 0, width: max(0.5, w * 0.003), height: size.height)), with: .color(Color(hex: "C0504D").opacity(0.75)))
        }
    }

    static func music(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        var lines = Path()
        var y = w * 0.08
        while y < size.height {
            for k in 0..<5 {
                let ly = y + CGFloat(k) * w * 0.013
                lines.move(to: CGPoint(x: w * 0.05, y: ly)); lines.addLine(to: CGPoint(x: size.width - w * 0.05, y: ly))
            }
            y += w * 0.13
        }
        ctx.stroke(lines, with: .color(ink), lineWidth: max(0.4, w * 0.002))
    }

    static func laid(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        var laid = Path(), chain = Path()
        var y: CGFloat = 0
        while y < size.height { laid.move(to: CGPoint(x: 0, y: y)); laid.addLine(to: CGPoint(x: size.width, y: y)); y += max(1.2, w * 0.008) }
        var x = w * 0.04
        while x < size.width { chain.move(to: CGPoint(x: x, y: 0)); chain.addLine(to: CGPoint(x: x, y: size.height)); x += w * 0.09 }
        ctx.stroke(laid, with: .color(ink.opacity(0.12)), lineWidth: 0.4)
        ctx.stroke(chain, with: .color(ink.opacity(0.3)), lineWidth: max(0.5, w * 0.003))
    }

    /// The airmail border: red and blue bars on the slant all the way round.
    static func airmail(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat) {
        let band = w * 0.055, bar = w * 0.05
        var frame = Path(CGRect(origin: .zero, size: size))
        frame.addRect(CGRect(origin: .zero, size: size).insetBy(dx: band, dy: band))
        var border = ctx
        border.clip(to: frame, style: FillStyle(eoFill: true))
        var red = Path(), blue = Path()
        var t: CGFloat = -size.height
        var i = 0
        while t < size.width + size.height {
            var slant = Path()
            slant.addLines([CGPoint(x: t, y: 0), CGPoint(x: t + bar, y: 0), CGPoint(x: t + bar + size.height, y: size.height), CGPoint(x: t + size.height, y: size.height)])
            slant.closeSubpath()
            if i % 4 == 0 { red.addPath(slant) } else if i % 4 == 2 { blue.addPath(slant) }
            t += bar
            i += 1
        }
        border.fill(red, with: .color(Color(hex: "C8352E")))
        border.fill(blue, with: .color(Color(hex: "2B4C9A")))
    }

    // MARK: Printed repeats

    static func glyphs(_ ctx: inout GraphicsContext, size: CGSize, glyph: String, spacing: CGFloat, glyphSize: CGFloat, inks: [Color],
                       offset: CGPoint = .zero, jitter: CGFloat = 0, seed: String = "") {
        var rng = SeededRandom(string: seed + glyph)
        let resolved = inks.map { ink -> GraphicsContext.ResolvedText in
            var text = ctx.resolve(Text(glyph + "\u{FE0E}").font(.system(size: glyphSize)))
            text.shading = .color(ink)
            return text
        }
        var row = 0
        var y = spacing / 2 + offset.y
        while y < size.height + spacing {
            var x = (row.isMultiple(of: 2) ? 0 : spacing / 2) + offset.x
            var col = 0
            while x < size.width + spacing {
                let j = jitter > 0 ? CGPoint(x: .random(in: -jitter...jitter, using: &rng), y: .random(in: -jitter...jitter, using: &rng)) : .zero
                ctx.draw(resolved[(row + col) % resolved.count], at: CGPoint(x: x + j.x, y: y + j.y))
                x += spacing
                col += 1
            }
            y += spacing * 0.75
            row += 1
        }
    }

    static func scatter(_ ctx: inout GraphicsContext, size: CGSize, glyph: String, count: Int, sizes: ClosedRange<CGFloat>, ink: Color, seed: String) {
        var rng = SeededRandom(string: seed + "scatter")
        for _ in 0..<count {
            var text = ctx.resolve(Text(glyph + "\u{FE0E}").font(.system(size: .random(in: sizes, using: &rng))))
            text.shading = .color(ink.opacity(.random(in: 0.5...1, using: &rng)))
            ctx.draw(text, at: CGPoint(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng)))
        }
    }

    static func words(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        var text = ctx.resolve(Text("BOOKS · BOOKSELLERS · STATIONERS · ").font(.custom("Copperplate-Bold", fixedSize: w * 0.04)).tracking(w * 0.004))
        text.shading = .color(ink)
        let lineWidth = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
        var slanted = ctx
        slanted.translateBy(x: size.width / 2, y: size.height / 2)
        slanted.rotate(by: .degrees(-30))
        let reach = hypot(size.width, size.height)
        var y = -reach / 2
        var row = 0
        while y < reach / 2 {
            var x = -reach / 2 - (row.isMultiple(of: 2) ? 0 : lineWidth / 2)
            while x < reach / 2 {
                slanted.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)
                x += lineWidth
            }
            y += w * 0.08
            row += 1
        }
    }

    // MARK: Curves

    static func scales(_ ctx: inout GraphicsContext, size: CGSize, r: CGFloat, ink: Color) {
        var path = Path()
        var row = 0
        var y: CGFloat = 0
        while y < size.height + r {
            var x = (row.isMultiple(of: 2) ? 0 : r) - r
            while x < size.width + r * 2 {
                path.move(to: CGPoint(x: x - r, y: y))
                path.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
                x += r * 2
            }
            y += r * 0.9
            row += 1
        }
        ctx.stroke(path, with: .color(ink), lineWidth: max(0.6, r * 0.08))
    }

    static func ripple(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        var path = Path()
        var y: CGFloat = 0
        var k: CGFloat = 0
        while y < size.height + w * 0.05 {
            var x: CGFloat = 0
            path.move(to: CGPoint(x: 0, y: y))
            while x <= size.width + 3 {
                path.addLine(to: CGPoint(x: x, y: y + w * 0.012 * sin(x / w * 18 + k * 0.9)))
                x += 2
            }
            y += w * 0.03
            k += 1
        }
        ctx.stroke(path, with: .color(ink), lineWidth: max(0.5, w * 0.004))
    }

    /// An ordnance survey sheet: contour rings round a few hills, a river, the grid.
    static func ordnance(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color, seed: String) {
        var rng = SeededRandom(string: seed + "map")
        var grid = Path()
        var t: CGFloat = 0
        while t < max(size.width, size.height) {
            grid.move(to: CGPoint(x: t, y: 0)); grid.addLine(to: CGPoint(x: t, y: size.height))
            grid.move(to: CGPoint(x: 0, y: t)); grid.addLine(to: CGPoint(x: size.width, y: t))
            t += w * 0.2
        }
        ctx.stroke(grid, with: .color(Color(hex: "3F6F86").opacity(0.35)), lineWidth: 0.5)
        for _ in 0..<4 {
            let c = CGPoint(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng))
            let phases = (0..<3).map { _ in CGFloat.random(in: 0..<(.pi * 2), using: &rng) }
            for ring in 1...7 {
                var contour = Path()
                let r0 = w * 0.04 * CGFloat(ring)
                for i in 0...72 {
                    let a = CGFloat(i) / 72 * 2 * .pi
                    let r = r0 * (1 + 0.18 * sin(a * 2 + phases[0]) + 0.1 * sin(a * 3 + phases[1]) + 0.06 * sin(a * 5 + phases[2]))
                    let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    if i == 0 { contour.move(to: p) } else { contour.addLine(to: p) }
                }
                ctx.stroke(contour, with: .color(ink.opacity(ring.isMultiple(of: 5) ? 0.8 : 0.45)),
                           lineWidth: ring.isMultiple(of: 5) ? max(0.6, w * 0.004) : 0.5)
            }
        }
        var river = Path()
        var x: CGFloat = -10
        let start = CGFloat.random(in: 0.3...0.7, using: &rng) * size.height
        river.move(to: CGPoint(x: x, y: start))
        while x < size.width + 10 {
            x += 6
            river.addLine(to: CGPoint(x: x, y: start + w * 0.08 * sin(x / w * 5) + w * 0.03 * sin(x / w * 13)))
        }
        ctx.stroke(river, with: .color(Color(hex: "3F6F86").opacity(0.8)), lineWidth: max(1, w * 0.008))
    }

    static func crossword(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color, seed: String) {
        let cell = w * 0.07
        let cols = Int(size.width / cell) + 1, rows = Int(size.height / cell) + 1
        var black = Path(), lines = Path()
        for j in 0..<rows {
            for i in 0..<cols {
                let square = CGRect(x: CGFloat(i) * cell, y: CGFloat(j) * cell, width: cell, height: cell)
                lines.addRect(square)
                // Symmetric about the centre, as a crossword's black squares are.
                let mirror = (cols - 1 - i) * 31 + (rows - 1 - j)
                let own = i * 31 + j
                var pick = SeededRandom(string: seed + "\(min(own, mirror))")
                if Int.random(in: 0..<5, using: &pick) == 0 { black.addRect(square) }
            }
        }
        ctx.fill(black, with: .color(ink.opacity(0.85)))
        ctx.stroke(lines, with: .color(ink.opacity(0.55)), lineWidth: max(0.4, w * 0.002))
    }

    static func trellis(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let step = w * 0.1
        var lines = Path(), leaves = Path()
        var x = -size.height
        while x < size.width + size.height {
            lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x + size.height, y: size.height))
            lines.move(to: CGPoint(x: x + size.height, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var lx: CGFloat = row.isMultiple(of: 2) ? step / 2 : 0
            while lx < size.width + step {
                leaves.addEllipse(in: CGRect(x: lx - w * 0.012, y: y - w * 0.02, width: w * 0.024, height: w * 0.04))
                lx += step
            }
            y += step / 2
            row += 1
        }
        ctx.stroke(lines, with: .color(ink.opacity(0.6)), lineWidth: max(0.5, w * 0.005))
        ctx.fill(leaves, with: .color(ink.opacity(0.75)))
    }

    static func quatrefoil(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let s = w * 0.12
        var rings = Path()
        var y: CGFloat = 0
        while y < size.height + s {
            var x: CGFloat = 0
            while x < size.width + s {
                rings.addEllipse(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
                rings.addEllipse(in: CGRect(x: x, y: y, width: s, height: s))
                x += s
            }
            y += s
        }
        ctx.stroke(rings, with: .color(ink), lineWidth: max(0.6, w * 0.006))
    }

    static func argyle(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, ink: Color) {
        let dw = w * 0.22, dh = w * 0.32
        var filled = Path(), dashes = Path()
        var j = 0
        var y: CGFloat = -dh
        while y < size.height + dh {
            var x: CGFloat = (j.isMultiple(of: 2) ? 0 : dw / 2) - dw
            while x < size.width + dw {
                var diamond = Path()
                diamond.addLines([CGPoint(x: x + dw / 2, y: y), CGPoint(x: x + dw, y: y + dh / 2), CGPoint(x: x + dw / 2, y: y + dh), CGPoint(x: x, y: y + dh / 2)])
                diamond.closeSubpath()
                if j.isMultiple(of: 2) { filled.addPath(diamond) }
                dashes.addPath(diamond)
                x += dw
            }
            y += dh / 2
            j += 1
        }
        ctx.fill(filled, with: .color(ink.opacity(0.75)))
        ctx.stroke(dashes, with: .color(Color(hex: "EFE6D2").opacity(0.85)), style: StrokeStyle(lineWidth: max(0.5, w * 0.004), dash: [w * 0.02, w * 0.015]))
    }

    /// Tissue: no print, only where it was folded.
    static func creases(_ ctx: inout GraphicsContext, size: CGSize, seed: String) {
        var rng = SeededRandom(string: seed + "tissue")
        for _ in 0..<5 {
            var crease = Path()
            let start = CGPoint(x: .random(in: 0..<size.width, using: &rng), y: 0)
            crease.move(to: start)
            crease.addLine(to: CGPoint(x: start.x + .random(in: -size.width...size.width, using: &rng) * 0.6, y: size.height))
            ctx.stroke(crease, with: .color(.white.opacity(0.35)), lineWidth: 1.2)
            ctx.stroke(crease.offsetBy(dx: 1, dy: 0), with: .color(.black.opacity(0.07)), lineWidth: 1)
        }
    }
}
