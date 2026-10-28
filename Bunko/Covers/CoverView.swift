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
                    GeometryReader { geo in
                        ObiView(obi: obi, japanese: book.rightToLeft || book.language.hasPrefix("ja"))
                            .frame(height: geo.size.height * (large ? 0.22 : 0.27))
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
            PlainCover(book: book, large: large)
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
            drawTexture(&ctx, size: size, rng: &rng)

            // The flaps fold round the boards a little in from each edge; the spine is shaded.
            let spineOnRight = book.rightToLeft
            for x in [size.width * 0.045, size.width * 0.955] {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.8 * unit, height: size.height)), with: .color(.black.opacity(0.10)))
                ctx.fill(Path(CGRect(x: x + 0.8 * unit, y: 0, width: 0.8 * unit, height: size.height)), with: .color(.white.opacity(0.12)))
            }
            let spineWidth = size.width * 0.07
            let spine = CGRect(x: spineOnRight ? size.width - spineWidth : 0, y: 0, width: spineWidth, height: size.height)
            ctx.fill(Path(spine), with: .linearGradient(
                Gradient(colors: [.black.opacity(0.22), .black.opacity(0)]),
                startPoint: CGPoint(x: spineOnRight ? size.width : 0, y: 0),
                endPoint: CGPoint(x: spineOnRight ? size.width - spineWidth : spineWidth, y: 0)))

            if style.showsLabel { drawLabel(&ctx, size: size, unit: unit) }
            if style.stampShape != .none { drawStamp(&ctx, size: size, ink: ink, unit: unit) }
        }
        .accessibilityElement()
        .accessibilityLabel("\(book.title), in a \(style.paper.label.lowercased()) paper cover")
    }

    private func drawTexture(_ ctx: inout GraphicsContext, size: CGSize, rng: inout SeededRandom) {
        let area = size.width * size.height
        switch style.paper.texture {
        case .speckle:
            for _ in 0..<Int(area / 90) {
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

    /// The title slip: up near the head, on the side away from the spine.
    private func drawLabel(_ ctx: inout GraphicsContext, size: CGSize, unit: CGFloat) {
        let fontSize = max(9, size.width * 0.075)
        let vertical = book.rightToLeft
        let paper = Color(hex: "F7F2E6")
        let inkColor = Color(hex: "2A241E")
        if vertical {
            let width = fontSize * 1.9
            let rect = CGRect(x: size.width * 0.16, y: size.height * 0.07, width: width, height: size.height * 0.55)
            ctx.fill(Path(rect), with: .color(paper))
            ctx.stroke(Path(rect.insetBy(dx: 2 * unit, dy: 2 * unit)), with: .color(inkColor.opacity(0.35)), lineWidth: 0.6 * unit)
            let maxChars = Int((rect.height - fontSize) / (fontSize * 1.08))
            let chars = Array(book.title.prefix(max(1, maxChars)))
            for (i, ch) in chars.enumerated() {
                ctx.draw(Text(String(ch)).font(Typesetter.swiftUIFont(.mincho, size: fontSize, bold: true)).foregroundColor(inkColor),
                         at: CGPoint(x: rect.midX, y: rect.minY + fontSize * 0.9 + CGFloat(i) * fontSize * 1.08))
            }
        } else {
            let rect = CGRect(x: size.width * 0.14, y: size.height * 0.1, width: size.width * 0.72, height: size.height * 0.22)
            ctx.fill(Path(rect), with: .color(paper))
            ctx.stroke(Path(rect.insetBy(dx: 2 * unit, dy: 2 * unit)), with: .color(inkColor.opacity(0.35)), lineWidth: 0.6 * unit)
            let title = Text(book.title).font(Typesetter.swiftUIFont(.serif, size: fontSize, bold: true)).foregroundColor(inkColor)
            var resolved = ctx.resolve(title)
            resolved.shading = .color(inkColor)
            ctx.draw(resolved, in: rect.insetBy(dx: 6 * unit, dy: 5 * unit).offsetBy(dx: 0, dy: 0))
            if !book.author.isEmpty {
                ctx.draw(Text(book.author).font(.custom("Literata-Italic", size: fontSize * 0.6)).foregroundColor(inkColor.opacity(0.7)),
                         at: CGPoint(x: rect.midX, y: rect.maxY - fontSize * 0.7))
            }
        }
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

/// A book with no cover art of its own, unwrapped: plain cloth with its title.
struct PlainCover: View {
    let book: Book
    var large = false

    var body: some View {
        let hue = Double(book.id.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 360 }) / 360
        ZStack {
            Color(hue: hue, saturation: 0.35, brightness: 0.45)
            VStack(spacing: large ? 18 : 6) {
                Text(book.title)
                    .font(Typesetter.swiftUIFont(.serif, size: large ? 34 : 13, bold: true))
                    .multilineTextAlignment(.center)
                if !book.author.isEmpty {
                    Text(book.author).font(.custom("Literata-Italic", size: large ? 20 : 9))
                }
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(large ? 40 : 10)
        }
    }
}
