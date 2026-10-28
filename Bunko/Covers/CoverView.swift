import SwiftUI

/// A book as you see it shut: in its paper cover, or (unwrapped) in its own cover, worn by how
/// much it has been read, and in its obi when there's something to say.
struct CoverView: View {
    let style: CoverStyle
    let book: Book
    var original: UIImage?
    /// Full screen (the closed book) rather than a shelf thumbnail: bigger type and stamp.
    var large = false
    var wear: Double = 0
    var obi: Obi?

    var body: some View {
        face
            .overlay { WearOverlay(wear: wear, seed: book.id, spineOnRight: book.rightToLeft) }
            .overlay(alignment: .bottom) {
                if let obi {
                    let kind = style.obi ?? .automatic(for: book.designKey)
                    GeometryReader { geo in
                        ObiView(obi: obi, japanese: book.rightToLeft || book.language.hasPrefix("ja"),
                                spineOnRight: book.rightToLeft, style: kind, title: book.title)
                            .printed(strength: large ? 1 : 0.75)
                            .frame(height: geo.size.height * kind.height(large: large))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    @ViewBuilder private var face: some View {
        if style.wrapped {
            PaperCover(style: style, book: book, large: large).printed(strength: large ? 1 : 0.75, grain: style.paper.grain)
        } else if let original {
            Color.clear
                .overlay(Image(uiImage: original).resizable().scaledToFill())
                .clipped()
        } else {
            HouseCover(book: book, large: large).printed(strength: large ? 1 : 0.75)
        }
    }
}

/// Bookshop paper folded round the book: textured paper, the creases of its flaps, the shop's
/// stamp, and a title slip (題簽), vertical for a Japanese book.
struct PaperCover: View {
    let style: CoverStyle
    let book: Book
    var large = false

    var body: some View {
        let base = UIColor(hex: style.baseHex)
        let ink = Color(hex: style.paper.ink)
        let unit: CGFloat = large ? 2.4 : 1
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            var rng = SeededRandom(string: book.id + style.paper.rawValue)
            if style.paper == .kraft && style.tint == nil {
                // The real thing: a scan of ribbed kraft wrapping paper.
                ctx.fill(Path(rect), with: .tiledImage(Image(uiImage: Print.kraft), scale: Print.tileScale(coverWidth: size.width)))
            } else {
                ctx.fill(Path(rect), with: .color(Color(uiColor: base)))
                drawTexture(&ctx, size: size, rng: &rng, base: Color(uiColor: base), ink: ink)
            }

            // The paper folds round the spine a little in from that edge, and the spine is shaded.
            let spineOnRight = book.rightToLeft
            let fold = size.width * (spineOnRight ? 0.955 : 0.045)
            ctx.fill(Path(CGRect(x: fold, y: 0, width: 0.8 * unit, height: size.height)), with: .color(.black.opacity(0.10)))
            ctx.fill(Path(CGRect(x: fold + 0.8 * unit, y: 0, width: 0.8 * unit, height: size.height)), with: .color(.white.opacity(0.12)))
            let spineWidth = size.width * 0.07
            let spine = CGRect(x: spineOnRight ? size.width - spineWidth : 0, y: 0, width: spineWidth, height: size.height)
            ctx.fill(Path(spine), with: .linearGradient(
                Gradient(colors: [.black.opacity(0.22), .black.opacity(0)]),
                startPoint: CGPoint(x: spineOnRight ? size.width : 0, y: 0),
                endPoint: CGPoint(x: spineOnRight ? size.width - spineWidth : spineWidth, y: 0)))
            // A shop's paper is folded over the head and the foot of the boards: a doubled edge and
            // its crease along each.
            let turn = max(2, size.height * 0.012)
            for y in [0, size.height - turn] {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: turn)), with: .color(.white.opacity(0.10)))
            }
            for y in [turn, size.height - turn - 0.7 * unit] {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.7 * unit)), with: .color(.black.opacity(0.10)))
            }

            if style.showsLabel { drawLabel(&ctx, size: size, unit: unit) }
            switch style.stampShape {
            case .none: break
            case .seal: drawSeal(&ctx, size: size, unit: unit)
            case .circle, .square: drawStamp(&ctx, size: size, ink: ink, unit: unit)
            }
        }
        // Patterns are drawn past the edges so they tile cleanly; the paper ends where the book does.
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("\(book.title), in a \(style.paper.label.lowercased()) paper cover")
    }

    private func drawTexture(_ ctx: inout GraphicsContext, size: CGSize, rng: inout SeededRandom, base: Color, ink: Color) {
        let area = size.width * size.height
        switch style.paper.texture {
        case .speckle, .waves, .hemp:
            if style.paper.texture == .waves { drawWaves(&ctx, size: size, base: base, ink: ink) }
            if style.paper.texture == .hemp { drawHemp(&ctx, size: size, ink: ink) }
            // The odd inclusion in the pulp; the scanned grain does the rest.
            for _ in 0..<Int(area / 700) {
                let r = CGFloat.random(in: 0.4...1.3, using: &rng)
                let p = CGRect(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng), width: r, height: r)
                ctx.fill(Path(ellipseIn: p), with: .color(Color(hex: "3A2A1A").opacity(.random(in: 0.05...0.14, using: &rng))))
            }
        case .fibers:
            // Washi's long fibres, few and faint: the scanned grain carries the paper itself.
            for _ in 0..<Int(area / 700) {
                let start = CGPoint(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng))
                let length = CGFloat.random(in: 4...18, using: &rng)
                let angle = CGFloat.random(in: 0..<(.pi * 2), using: &rng)
                var fiber = Path()
                fiber.move(to: start)
                fiber.addQuadCurve(
                    to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length),
                    control: CGPoint(x: start.x + cos(angle + 0.6) * length * 0.5, y: start.y + sin(angle + 0.6) * length * 0.5))
                let light = Bool.random(using: &rng)
                ctx.stroke(fiber, with: .color((light ? Color.white : .black).opacity(.random(in: 0.05...0.14, using: &rng))), lineWidth: 0.4)
            }
        case .weave, .lines:
            // Bookcloth and newsprint are all in their scanned grain.
            break
        }
    }

    /// 青海波: rows of fanned rings, each row tucked over the one above so only the arches show.
    private func drawWaves(_ ctx: inout GraphicsContext, size: CGSize, base: Color, ink: Color) {
        let r = size.width * 0.075
        var y = -r / 2
        var row = 0
        while y < size.height + r {
            var x = (row.isMultiple(of: 2) ? 0 : r) - 2 * r
            while x < size.width + 2 * r {
                let fan = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: fan), with: .color(base))
                var rings = Path()
                for k in 0..<4 { rings.addEllipse(in: fan.insetBy(dx: r * CGFloat(k) * 0.24, dy: r * CGFloat(k) * 0.24)) }
                ctx.stroke(rings, with: .color(ink.opacity(0.26)), lineWidth: max(0.5, r * 0.055))
                x += r * 2
            }
            y += r / 2
            row += 1
        }
    }

    /// 麻の葉: a grid of triangles, each with its centre joined to its corners, so six-pointed
    /// hemp leaves open round every crossing.
    private func drawHemp(_ ctx: inout GraphicsContext, size: CGSize, ink: Color) {
        let a = size.width * 0.17
        let h = a * sqrt(3) / 2
        var lines = Path()
        for j in -1...Int(size.height / h) + 1 {
            let top = CGFloat(j) * h, bottom = top + h
            let topShift: CGFloat = j.isMultiple(of: 2) ? 0 : a / 2
            for k in -1...Int(size.width / a) + 1 {
                let t0 = CGPoint(x: CGFloat(k) * a + topShift, y: top), t1 = CGPoint(x: t0.x + a, y: top)
                let b0 = CGPoint(x: t0.x - a / 2, y: bottom), b1 = CGPoint(x: b0.x + a, y: bottom)
                for triangle in [[t0, t1, CGPoint(x: t0.x + a / 2, y: bottom)], [b0, b1, CGPoint(x: b0.x + a / 2, y: top)]] {
                    let centre = CGPoint(x: triangle.map(\.x).reduce(0, +) / 3, y: triangle.map(\.y).reduce(0, +) / 3)
                    lines.addLines(triangle + [triangle[0]])
                    for corner in triangle {
                        lines.move(to: centre)
                        lines.addLine(to: corner)
                    }
                }
            }
        }
        ctx.stroke(lines, with: .color(ink.opacity(0.32)), lineWidth: max(0.5, a * 0.022))
    }

    /// The title slip: up near the head, on the side away from the spine. The whole title always
    /// fits: a vertical one shrinks, then runs on into a second column (read right to left); a
    /// horizontal one wraps, then shrinks.
    private func drawLabel(_ ctx: inout GraphicsContext, size: CGSize, unit: CGFloat) {
        let fontSize = max(9, size.width * 0.075)
        let vertical = book.rightToLeft
        let inkColor = Color(hex: "2A241E")
        // A volume number is printed on the slip when the title doesn't already carry it.
        let number = book.series != nil ? book.volume?.index : nil
        if vertical {
            let chars = Array(book.title)
            let height = size.height * 0.55
            let numberRoom = number == nil ? 0 : fontSize * 1.6
            let (columns, glyph) = Self.verticalSlip(count: chars.count, base: fontSize, height: height - numberRoom)
            let column = glyph * 1.15
            let rect = CGRect(x: size.width * 0.16, y: size.height * 0.07, width: glyph * 1.9 + column * CGFloat(columns - 1), height: height)
            var slip = pasteSlip(ctx, rect: rect, unit: unit)
            let perColumn = (chars.count + columns - 1) / columns
            for (i, ch) in chars.enumerated() {
                let c = CGFloat(i / perColumn), row = CGFloat(i % perColumn)
                slip.draw(Text(String(ch)).font(Typesetter.swiftUIFont(.mincho, size: glyph, bold: true)).foregroundColor(inkColor),
                          at: CGPoint(x: rect.maxX - glyph * 0.95 - c * column, y: rect.minY + glyph * 0.9 + row * glyph * 1.08))
            }
            if let number {
                slip.draw(Text(Book.Volume.kanji(number)).font(Typesetter.swiftUIFont(.mincho, size: fontSize * 0.8)).foregroundColor(inkColor),
                          at: CGPoint(x: rect.maxX - glyph * 0.95, y: rect.maxY - fontSize * 0.9))
            }
        } else {
            let rect = CGRect(x: size.width * 0.14, y: size.height * 0.1, width: size.width * 0.72, height: size.height * 0.22)
            var slip = pasteSlip(ctx, rect: rect, unit: unit)
            let byline = book.author.isEmpty && number == nil ? 0 : fontSize * 0.95
            let room = CGRect(x: rect.minX + 6 * unit, y: rect.minY + 5 * unit,
                              width: rect.width - 12 * unit, height: rect.height - 10 * unit - byline)
            let (lines, lineHeight) = Self.setTitle(book.title, ctx: slip, width: room.width, height: room.height, base: fontSize)
            let top = room.midY - lineHeight * CGFloat(lines.count) / 2
            for (i, line) in lines.enumerated() {
                var line = line
                line.shading = .color(inkColor)
                slip.draw(line, at: CGPoint(x: room.midX, y: top + lineHeight * (CGFloat(i) + 0.5)), anchor: .center)
            }
            // The author (and the volume, when the title doesn't say), shrunk rather than cut.
            let byText = [book.author, number.map { "Vol. \(Book.Volume.label($0))" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
            if !byText.isEmpty {
                var author = slip.resolve(Text(byText).font(.custom("Literata-Italic", size: fontSize * 0.6)))
                let wide = author.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
                if wide > room.width {
                    author = slip.resolve(Text(byText).font(.custom("Literata-Italic", size: fontSize * 0.6 * room.width / wide)))
                }
                author.shading = .color(inkColor.opacity(0.7))
                slip.draw(author, at: CGPoint(x: rect.midX, y: rect.maxY - fontSize * 0.7))
            }
        }
    }

    /// The title slip pasted on: washi a shade off the cover's colour, set a touch crooked, lifted
    /// by its own thickness, with a thin printed frame. Returns the slip's context to write on.
    private func pasteSlip(_ ctx: GraphicsContext, rect: CGRect, unit: CGFloat) -> GraphicsContext {
        var rng = SeededRandom(string: book.id + "slip")
        var slip = ctx
        slip.translateBy(x: rect.midX, y: rect.midY)
        slip.rotate(by: .degrees(Double.random(in: -0.7...0.7, using: &rng)))
        slip.translateBy(x: -rect.midX, y: -rect.midY)
        var lifted = slip
        lifted.addFilter(.shadow(color: .black.opacity(0.22), radius: 0.9 * unit, x: 0.3 * unit, y: 0.7 * unit))
        lifted.fill(Path(rect), with: .color(Color(hex: "F4EEE0")))
        // Washi: long soft fibres, and its edges not quite straight.
        for _ in 0..<Int(rect.width * rect.height / (60 * unit * unit)) {
            let start = CGPoint(x: .random(in: rect.minX...rect.maxX, using: &rng), y: .random(in: rect.minY...rect.maxY, using: &rng))
            let length = CGFloat.random(in: 4...14, using: &rng) * unit, angle = CGFloat.random(in: 0..<(.pi * 2), using: &rng)
            var fibre = Path()
            fibre.move(to: start)
            fibre.addQuadCurve(to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length),
                               control: CGPoint(x: start.x + cos(angle + 0.7) * length * 0.5, y: start.y + sin(angle + 0.7) * length * 0.5))
            slip.stroke(fibre, with: .color(Color(hex: "B9AE98").opacity(.random(in: 0.12...0.3, using: &rng))), lineWidth: 0.4 * unit)
        }
        slip.stroke(Path(rect.insetBy(dx: 2.6 * unit, dy: 2.6 * unit)), with: .color(Color(hex: "2A241E").opacity(0.28)), lineWidth: 0.5 * unit)
        return slip
    }

    /// A horizontal title in centred lines, broken between words, at the biggest size from `base`
    /// down (to a third) at which every word fits the width and every line the height.
    static func setTitle(_ title: String, ctx: GraphicsContext, width: CGFloat, height: CGFloat,
                         base: CGFloat) -> (lines: [GraphicsContext.ResolvedText], lineHeight: CGFloat) {
        var size = base
        while true {
            let font = Typesetter.swiftUIFont(.serif, size: size, bold: true)
            func measure(_ text: String) -> CGFloat {
                ctx.resolve(Text(text).font(font)).measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
            }
            var lines: [String] = []
            var fits = true
            for word in title.split(separator: " ").map(String.init) {
                if let last = lines.last, measure(last + " " + word) <= width {
                    lines[lines.count - 1] = last + " " + word
                } else {
                    lines.append(word)
                    if measure(word) > width { fits = false }
                }
            }
            let lineHeight = size * 1.18
            if (fits && CGFloat(lines.count) * lineHeight <= height) || size <= base * 0.35 {
                return (lines.map { ctx.resolve(Text($0).font(font)) }, lineHeight)
            }
            size *= 0.92
        }
    }

    /// A vertical title slip's columns and type size: one column at the usual size if it fits,
    /// shrunk to fit if that keeps it readable (62%), else two columns.
    static func verticalSlip(count: Int, base: CGFloat, height: CGFloat) -> (columns: Int, size: CGFloat) {
        func fit(_ perColumn: Int) -> CGFloat { min(base, height / (1.08 * CGFloat(max(1, perColumn)) + 0.6)) }
        let one = fit(count)
        if one >= base * 0.62 { return (1, one) }
        return (2, fit((count + 1) / 2))
    }

    /// The shop's stamp, inked a little crooked near the foot.
    private func drawStamp(_ ctx: inout GraphicsContext, size: CGSize, ink: Color, unit: CGFloat) {
        let diameter = size.width * 0.34
        let center = CGPoint(x: book.rightToLeft ? size.width * 0.36 : size.width * 0.66, y: size.height * 0.8)
        var stamp = ctx
        stamp.translateBy(x: center.x, y: center.y)
        stamp.rotate(by: .degrees(-9))
        stamp.opacity = 0.85
        var rng = SeededRandom(string: book.id + style.stamp + "stamp")
        stamp.drawLayer { stamp in
            let box = CGRect(x: -diameter / 2, y: -diameter / 2, width: diameter, height: diameter)
            let outline = style.stampShape == .circle ? Path(ellipseIn: box) : Path(roundedRect: box.insetBy(dx: 0, dy: diameter * 0.12), cornerRadius: 2 * unit)
            stamp.stroke(outline, with: .color(ink), lineWidth: max(1, diameter * 0.035))
            stamp.stroke(style.stampShape == .circle ? Path(ellipseIn: box.insetBy(dx: diameter * 0.07, dy: diameter * 0.07))
                                                     : Path(roundedRect: box.insetBy(dx: diameter * 0.07, dy: diameter * 0.19), cornerRadius: unit),
                         with: .color(ink), lineWidth: max(0.5, diameter * 0.012))
            if style.paper == .basil {
                var cat = stamp.resolve(Image(systemName: "cat.fill"))
                cat.shading = .color(ink)
                stamp.draw(cat, in: CGRect(x: -diameter * 0.16, y: -diameter * 0.3, width: diameter * 0.32, height: diameter * 0.26))
            }
            // One line, or two split at the space nearest the middle; each shrunk to fit the ring.
            let lines = Self.stampLines(style.stamp)
            let lineHeight = diameter * 0.15
            let centerY = style.paper == .basil ? diameter * 0.16 : 0
            for (i, line) in lines.enumerated() {
                let base = diameter * 0.12
                var text = stamp.resolve(Text(line).font(.system(size: base, weight: .heavy, design: .serif)).tracking(diameter * 0.008))
                let width = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
                let room = diameter * (lines.count == 1 ? 0.72 : 0.66)
                if width > room {
                    text = stamp.resolve(Text(line).font(.system(size: base * room / width, weight: .heavy, design: .serif))
                        .tracking(diameter * 0.008 * room / width))
                }
                text.shading = .color(ink)
                let y = centerY + (CGFloat(i) - CGFloat(lines.count - 1) / 2) * lineHeight
                stamp.draw(text, at: CGPoint(x: 0, y: y))
            }
            // Pressed by hand: the ink skips in places, more towards one side.
            stamp.blendMode = .destinationOut
            for _ in 0..<Int(diameter * diameter / 5) {
                let p = CGPoint(x: .random(in: box.minX...box.maxX, using: &rng), y: .random(in: box.minY...box.maxY, using: &rng))
                guard CGFloat.random(in: 0...1, using: &rng) < 0.25 + 0.5 * (p.x - box.minX) / box.width else { continue }
                let r = diameter * .random(in: 0.003...0.011, using: &rng)
                stamp.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color(.black.opacity(.random(in: 0.3...0.9, using: &rng))))
            }
        }
    }

    /// A vermilion seal (朱印) in place of the stamp: a solid block with the letters cut out of it,
    /// Japanese in columns read right to left, anything else in rows, pressed a little crooked,
    /// the ink thin towards one corner and round the edges.
    private func drawSeal(_ ctx: inout GraphicsContext, size: CGSize, unit: CGFloat) {
        let (lines, vertical) = CoverStyle.sealLines(style.stamp)
        guard !lines.isEmpty else { return }
        // Laid out on a 100pt grid, then scaled to fit near the foot.
        let em: CGFloat = 100
        let font = Typesetter.swiftUIFont(.mincho, size: em * 0.84, bold: true)
        let pad = em * 0.3
        let rows = lines.map { ctx.resolve(Text($0).font(font).tracking(em * 0.04)) }
        let content = vertical
            ? CGSize(width: em * CGFloat(lines.count), height: em * CGFloat(lines.map(\.count).max() ?? 1))
            : CGSize(width: rows.map { $0.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: em)).width }.max() ?? em,
                     height: em * 0.92 * CGFloat(lines.count))
        let box = CGRect(x: 0, y: 0, width: content.width + pad * 2, height: content.height + pad * 2)
        var seal = ctx
        seal.translateBy(x: book.rightToLeft ? size.width * 0.36 : size.width * 0.68, y: size.height * 0.8)
        seal.rotate(by: .degrees(-4))
        seal.scaleBy(x: min(size.width * 0.3 / box.width, size.height * 0.2 / box.height),
                     y: min(size.width * 0.3 / box.width, size.height * 0.2 / box.height))
        seal.translateBy(x: -box.midX, y: -box.midY)
        seal.opacity = 0.9
        var rng = SeededRandom(string: book.id + style.stamp + "seal")
        seal.drawLayer { layer in
            layer.fill(Path(roundedRect: box, cornerRadius: em * 0.1), with: .color(Color(hex: "C23A22")))
            layer.blendMode = .destinationOut
            if vertical {
                let tallest = CGFloat(lines.map(\.count).max() ?? 1)
                for (c, column) in lines.enumerated() {
                    let x = box.maxX - pad - em * (CGFloat(c) + 0.5)
                    let top = pad + em * (tallest - CGFloat(column.count)) / 2
                    for (r, letter) in column.enumerated() {
                        var text = layer.resolve(Text(String(letter)).font(font))
                        text.shading = .color(.black)
                        layer.draw(text, at: CGPoint(x: x, y: top + em * (CGFloat(r) + 0.5)))
                    }
                }
            } else {
                for (i, row) in rows.enumerated() {
                    var text = row
                    text.shading = .color(.black)
                    layer.draw(text, at: CGPoint(x: box.midX, y: pad + em * 0.92 * (CGFloat(i) + 0.5)))
                }
            }
            // Where the ink was thin the paper shows through as a fine grain, more so away from
            // the top left and along the edges.
            for _ in 0..<Int(box.width * box.height / (em * em) * 260) {
                let p = CGPoint(x: .random(in: box.minX...box.maxX, using: &rng), y: .random(in: box.minY...box.maxY, using: &rng))
                let edge = min(p.x - box.minX, box.maxX - p.x, p.y - box.minY, box.maxY - p.y) / em
                let thin = 0.1 + 0.25 * (p.x / box.width + p.y / box.height) + (edge < 0.08 ? 0.5 : 0)
                guard CGFloat.random(in: 0...1, using: &rng) < thin else { continue }
                let r = em * .random(in: 0.006...0.022, using: &rng)
                layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color(.black.opacity(.random(in: 0.25...0.8, using: &rng))))
            }
        }
    }

    static func stampLines(_ stamp: String) -> [String] {
        let text = stamp.uppercased().trimmingCharacters(in: .whitespaces)
        guard text.count > 11, text.contains(" ") else { return [text] }
        if let dot = text.range(of: " · ") {
            return [String(text[..<dot.lowerBound]), String(text[dot.upperBound...])]
        }
        let middle = text.count / 2
        let spaces = text.indices.filter { text[$0] == " " }
        let split = spaces.min { abs(text.distance(from: text.startIndex, to: $0) - middle) < abs(text.distance(from: text.startIndex, to: $1) - middle) }!
        let first = text[..<split].trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
        let second = text[text.index(after: split)...].trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
        return [first, second].filter { !$0.isEmpty }
    }
}
