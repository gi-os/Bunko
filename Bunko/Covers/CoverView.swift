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
                            .frame(height: geo.size.height * kind.height(large: large))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    @ViewBuilder private var face: some View {
        if style.wrapped {
            PaperCover(style: style, book: book, large: large)
        } else if let original {
            Color.clear
                .overlay(Image(uiImage: original).resizable().scaledToFill())
                .clipped()
        } else {
            HouseCover(book: book, large: large)
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
            ctx.fill(Path(rect), with: .color(Color(uiColor: base)))
            var rng = SeededRandom(string: book.id + style.paper.rawValue)
            drawTexture(&ctx, size: size, rng: &rng, base: Color(uiColor: base), ink: ink)

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

            if style.showsLabel {
                drawLabel(&ctx, size: size, unit: unit)
            } else if let number = book.volume?.index {
                drawVolume(&ctx, number: number, at: CGPoint(x: spineOnRight ? size.width * 0.2 : size.width * 0.8, y: size.height * 0.1),
                           size: max(9, size.width * 0.075))
            }
            switch style.stampShape {
            case .none: break
            case .seal: drawSeal(&ctx, size: size, unit: unit)
            case .circle, .square: drawStamp(&ctx, size: size, ink: ink, unit: unit)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(book.title), in a \(style.paper.label.lowercased()) paper cover")
    }

    private func drawTexture(_ ctx: inout GraphicsContext, size: CGSize, rng: inout SeededRandom, base: Color, ink: Color) {
        let area = size.width * size.height
        switch style.paper.texture {
        case .speckle, .waves, .hemp:
            if style.paper.texture == .waves { drawWaves(&ctx, size: size, base: base, ink: ink) }
            if style.paper.texture == .hemp { drawHemp(&ctx, size: size, ink: ink) }
            // Printed papers get a finer grain over the print.
            for _ in 0..<Int(area / (style.paper.texture == .speckle ? 90 : 180)) {
                let r = CGFloat.random(in: 0.4...1.6, using: &rng)
                let p = CGRect(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng), width: r, height: r)
                let dark = Bool.random(using: &rng)
                ctx.fill(Path(ellipseIn: p), with: .color((dark ? Color.black : .white).opacity(.random(in: 0.05...0.16, using: &rng))))
            }
        case .fibers:
            for _ in 0..<Int(area / 260) {
                let start = CGPoint(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng))
                let length = CGFloat.random(in: 4...18, using: &rng)
                let angle = CGFloat.random(in: 0..<(.pi * 2), using: &rng)
                var fiber = Path()
                fiber.move(to: start)
                fiber.addQuadCurve(
                    to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length),
                    control: CGPoint(x: start.x + cos(angle + 0.6) * length * 0.5, y: start.y + sin(angle + 0.6) * length * 0.5))
                let light = Bool.random(using: &rng)
                ctx.stroke(fiber, with: .color((light ? Color.white : .black).opacity(.random(in: 0.08...0.22, using: &rng))), lineWidth: 0.6)
            }
        case .weave:
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: .color(.black.opacity(0.05)))
                y += 2.5
            }
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.6, height: size.height)), with: .color(.white.opacity(0.09)))
                x += 2.5
            }
        case .lines:
            var y: CGFloat = size.height * 0.08
            while y < size.height * 0.95 {
                let inset = CGFloat.random(in: 0...size.width * 0.3, using: &rng)
                ctx.fill(Path(CGRect(x: size.width * 0.1, y: y, width: size.width * 0.8 - inset, height: 1.2)),
                         with: .color(.black.opacity(0.06)))
                y += 5
            }
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
        let paper = Color(hex: "F7F2E6")
        let inkColor = Color(hex: "2A241E")
        if vertical {
            let chars = Array(book.title)
            let height = size.height * 0.55
            let (columns, glyph) = Self.verticalSlip(count: chars.count, base: fontSize, height: height)
            let column = glyph * 1.15
            let rect = CGRect(x: size.width * 0.16, y: size.height * 0.07, width: glyph * 1.9 + column * CGFloat(columns - 1), height: height)
            ctx.fill(Path(rect), with: .color(paper))
            ctx.stroke(Path(rect.insetBy(dx: 2 * unit, dy: 2 * unit)), with: .color(inkColor.opacity(0.35)), lineWidth: 0.6 * unit)
            let perColumn = (chars.count + columns - 1) / columns
            for (i, ch) in chars.enumerated() {
                let c = CGFloat(i / perColumn), row = CGFloat(i % perColumn)
                ctx.draw(Text(String(ch)).font(Typesetter.swiftUIFont(.mincho, size: glyph, bold: true)).foregroundColor(inkColor),
                         at: CGPoint(x: rect.maxX - glyph * 0.95 - c * column, y: rect.minY + glyph * 0.9 + row * glyph * 1.08))
            }
            if let number = book.volume?.index { drawVolume(&ctx, number: number, at: CGPoint(x: rect.maxX, y: rect.maxY), size: fontSize) }
        } else {
            let rect = CGRect(x: size.width * 0.14, y: size.height * 0.1, width: size.width * 0.72, height: size.height * 0.22)
            ctx.fill(Path(rect), with: .color(paper))
            ctx.stroke(Path(rect.insetBy(dx: 2 * unit, dy: 2 * unit)), with: .color(inkColor.opacity(0.35)), lineWidth: 0.6 * unit)
            let byline = book.author.isEmpty ? 0 : fontSize * 0.95
            let room = CGRect(x: rect.minX + 6 * unit, y: rect.minY + 5 * unit,
                              width: rect.width - 12 * unit, height: rect.height - 10 * unit - byline)
            let (lines, lineHeight) = Self.setTitle(book.title, ctx: ctx, width: room.width, height: room.height, base: fontSize)
            let top = room.midY - lineHeight * CGFloat(lines.count) / 2
            for (i, line) in lines.enumerated() {
                var line = line
                line.shading = .color(inkColor)
                ctx.draw(line, at: CGPoint(x: room.midX, y: top + lineHeight * (CGFloat(i) + 0.5)), anchor: .center)
            }
            if !book.author.isEmpty {
                // The author too, shrunk rather than cut.
                var author = ctx.resolve(Text(book.author).font(.custom("Literata-Italic", size: fontSize * 0.6)))
                let wide = author.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
                if wide > room.width {
                    author = ctx.resolve(Text(book.author).font(.custom("Literata-Italic", size: fontSize * 0.6 * room.width / wide)))
                }
                author.shading = .color(inkColor.opacity(0.7))
                ctx.draw(author, at: CGPoint(x: rect.midX, y: rect.maxY - fontSize * 0.7))
            }
            if let number = book.volume?.index { drawVolume(&ctx, number: number, at: CGPoint(x: rect.maxX, y: rect.maxY), size: fontSize) }
        }
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

    /// A volume's number on a round vermilion sticker, the way a series is told apart on the shelf.
    private func drawVolume(_ ctx: inout GraphicsContext, number: Double, at centre: CGPoint, size: CGFloat) {
        let d = size * 1.25
        ctx.fill(Path(ellipseIn: CGRect(x: centre.x - d / 2, y: centre.y - d / 2, width: d, height: d)), with: .color(Color(hex: "C23A22")))
        var text = ctx.resolve(Text(Book.Volume.label(number)).font(.system(size: size * 0.72, weight: .heavy, design: .serif)))
        text.shading = .color(Color(hex: "F7F2E6"))
        ctx.draw(text, at: centre)
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
        stamp.opacity = 0.82
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
