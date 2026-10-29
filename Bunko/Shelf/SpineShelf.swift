import SwiftUI

/// The shelf seen as a real one is: books standing spine out, side by side, on wooden shelves.
/// Each spine is its cover's: the bookshop's paper with a title slip, the publisher's house style
/// (白鷺, 月影, 青林, 千鳥, 灯台), or for a book with its own art, the art's colour.
struct SpineShelfView: View {
    let books: [Book]
    let spine: (Book) -> BookSpine
    let open: (Book) -> Void
    let menu: (Book) -> AnyView

    var body: some View {
        GeometryReader { geo in
            let widths = books.map { spine($0).width }
            let rows = SpineShelf.rows(widths: widths, available: geo.size.width - 44, spacing: SpineShelf.gap)
            ScrollView {
                VStack(spacing: 26) {
                    ForEach(rows.indices, id: \.self) { r in
                        VStack(spacing: 0) {
                            HStack(alignment: .bottom, spacing: SpineShelf.gap) {
                                ForEach(rows[r], id: \.self) { i in
                                    spine(books[i])
                                        .onTapGesture { open(books[i]) }
                                        .contextMenu { menu(books[i]) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 22)
                            ShelfPlank()
                        }
                    }
                }
                .padding(.vertical, 18)
            }
        }
    }
}

enum SpineShelf {
    static let gap: CGFloat = 1.5

    /// Books into shelves, left to right, a new shelf when the next spine won't fit.
    static func rows(widths: [CGFloat], available: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var row: [Int] = []
        var used: CGFloat = 0
        for (i, width) in widths.enumerated() {
            let needed = row.isEmpty ? width : used + spacing + width
            if !row.isEmpty && needed > available {
                rows.append(row)
                row = [i]
                used = width
            } else {
                row.append(i)
                used = needed
            }
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    /// How thick a book stands: its pages (a bunko page holds about 650 Japanese characters or
    /// 1,600 Western ones, a leaf is two pages), at a bunko's scale, with a little of each
    /// book's own to it, as real books differ.
    static func width(characters: Int, japanese: Bool, id: String) -> CGFloat {
        let pages = Double(characters) / (japanese ? 650 : 1600)
        let own = Double(id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % 7)
        return CGFloat(min(58, max(24, 22 + pages * 0.07 + own * 1.4)))
    }

    /// Characters in a book's file, estimated from its size: UTF-8 Japanese is three bytes a
    /// character; an EPUB is compressed markup.
    static func characters(bytes: Int, format: Book.Format, japanese: Bool) -> Int {
        switch format {
        case .txt: japanese ? bytes / 3 : bytes
        case .epub: japanese ? bytes * 2 / 3 : bytes * 3 / 2
        }
    }
}

/// One book's spine.
struct BookSpine: View {
    let book: Book
    let style: CoverStyle
    let original: UIImage?
    let width: CGFloat
    static let height: CGFloat = 214

    /// Columns down the spine for a Japanese book; everything else runs top to bottom.
    private var japanese: Bool { book.setVertically }
    /// An English edition: the house's English name and colophon letter, as its cover has them.
    private var english: Bool { !book.printsJapanese }
    private var house: House { .of(book, imprint: style.house) }
    private var colour: Color { Color(hex: house.colour) }
    /// Which of its house's three layouts this copy wears, as its cover does.
    private var variant: Int { house.variant % 3 }
    private var coverWidth: CGFloat { Self.height * 105 / 148 }
    private let cream = Color(hex: "F5F0E4")
    private let ink = Color(hex: "26221D")

    var body: some View {
        let h = Self.height
        ZStack {
            face(w: width, h: h)
                .blur(radius: 0.25)
                .overlay(Image(uiImage: Print.mottle).resizable(resizingMode: .tile).blendMode(.screen).opacity(0.45))
                .overlay(paperGrain(style.wrapped ? style.paper.grain : .tooth).blendMode(.softLight).opacity(0.85))
            // A paperback's spine is rounded: shadowed at both edges, catching the light a third across.
            LinearGradient(stops: [.init(color: .black.opacity(0.30), location: 0),
                                   .init(color: .white.opacity(0.12), location: 0.32),
                                   .init(color: .clear, location: 0.62),
                                   .init(color: .black.opacity(0.26), location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .frame(width: width, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 1.5, x: 1, y: 0)
        .accessibilityElement()
        .accessibilityLabel(book.author.isEmpty ? book.title : "\(book.title), \(book.author)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private func face(w: CGFloat, h: CGFloat) -> some View {
        if style.wrapped {
            // The bookshop's paper, with a slip for the title as the front has.
            let paperInk = Color(hex: style.paper.ink)
            VStack(spacing: 0) {
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: paperInk)
                    .padding(.vertical, 6).frame(width: w * 0.66, height: h * 0.62)
                    .background(cream).overlay(Rectangle().stroke(paperInk.opacity(0.3), lineWidth: 0.5))
                    .padding(.top, h * 0.07)
                Spacer()
            }
            .frame(width: w, height: h)
            .background { wrapper }
        } else if let original {
            let tone = Self.tone(of: original)
            VStack(spacing: h * 0.04) {
                SpineText(book.title, vertical: japanese, size: w * 0.48, bold: true, colour: tone.text)
                    .frame(height: h * 0.6)
                SpineText(book.author, vertical: japanese, size: w * 0.32, bold: false, colour: tone.text.opacity(0.8))
                    .frame(height: h * 0.26)
            }
            .padding(.vertical, h * 0.04)
            .frame(width: w, height: h)
            .background(tone.background)
        } else {
            houseFace(w: w, h: h)
        }
    }

    /// The house's spine, as its covers: the same band, colour, rules and stripes. The title
    /// takes whatever height the author, the shelf code and the foot leave it.
    @ViewBuilder private func houseFace(w: CGFloat, h: CGFloat) -> some View {
        let gap = h * 0.02
        let author = { (colour: Color, gothic: Bool) in
            SpineText(book.author, vertical: japanese, size: w * 0.32, bold: false, colour: colour, gothic: gothic)
                .frame(height: h * 0.15)
        }
        switch house.imprint {
        case .shirasagi:
            VStack(spacing: gap) {
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: cream)
                    .padding(.vertical, h * 0.03).frame(maxHeight: h * [0.5, 0.42, 0.6][variant]).frame(width: w).background(colour)
                author(colour, false)
                Spacer(minLength: 0)
                shelfCode(colour)
                foot(colour)
            }
            .frame(width: w, height: h).background(cream)
        case .tsukikage:
            VStack(spacing: gap) {
                VStack(spacing: 1.5) {
                    Rectangle().fill(cream.opacity(0.8)).frame(height: variant == 1 ? 1.8 : 0.8)
                    if variant == 0 { Rectangle().fill(cream.opacity(0.8)).frame(height: 0.5) }
                }
                .opacity(variant == 2 ? 0 : 1)
                .padding(.top, h * 0.03)
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: cream).frame(maxHeight: .infinity)
                author(cream.opacity(0.85), false)
                shelfCode(cream)
                foot(cream)
            }
            .frame(width: w, height: h).background(colour)
            .overlay {
                if variant == 2 { RoundedRectangle(cornerRadius: 3).stroke(cream.opacity(0.8), lineWidth: 0.7).padding(2.5) }
            }
        case .seirin:
            VStack(spacing: gap) {
                Rectangle().fill(colour).frame(height: h * 0.035)
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: ink).frame(maxHeight: .infinity)
                author(colour, false)
                foot(cream).padding(.top, 3).frame(maxWidth: .infinity).background(colour)
            }
            .frame(width: w, height: h)
            .background(variant == 1 ? Color(uiColor: UIColor(hex: house.colour).mixed(with: UIColor(cream), 0.78)) : cream)
        case .chidori:
            VStack(spacing: gap) {
                // 矢絣, as the cover prints it.
                ArrowFeathers(column: coverWidth * [0.14, 0.1, 0.19][variant]).fill(colour)
                    .rotationEffect(.degrees(variant == 2 ? 180 : 0))
                    .frame(height: h * 0.1).clipped()
                SpineText(book.title, vertical: japanese, size: w * 0.48, bold: true, colour: ink).frame(maxHeight: .infinity)
                author(colour, false)
                shelfCode(colour)
                foot(colour)
            }
            .frame(width: w, height: h).background(cream)
        case .todai:
            VStack(spacing: gap) {
                SpineText(book.title, vertical: japanese, size: w * 0.52, bold: true, colour: cream, gothic: true)
                    .frame(maxHeight: .infinity).padding(.top, h * 0.04)
                Rectangle().fill(cream).frame(width: w * 0.4, height: 0.8)
                author(cream.opacity(0.85), true)
                foot(cream)
            }
            .frame(width: w, height: h).background(colour)
        default:
            craftFace(w: w, h: h)
        }
    }

    /// The author's shelf code, stacked in its rounded box as bunko spines carry it (や / 5 / 51).
    private func shelfCode(_ colour: Color) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(house.shelfCode.split(separator: " ").enumerated()), id: \.offset) { _, part in
                Text(part).font(.system(size: 6.5, weight: .medium)).monospacedDigit()
            }
        }
        .foregroundStyle(colour)
        .padding(.vertical, 2).padding(.horizontal, 1.5)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(colour, lineWidth: 0.5))
    }

    /// The house's colophon in its printed ring and its name, as the covers carry them: the kanji
    /// and the name in a column for a Japanese book; for an English edition the letter in Literata
    /// and the name in tracked capitals, run down the spine.
    private func foot(_ colour: Color) -> some View {
        VStack(spacing: 2) {
            Text(house.imprint.colophon(english: english))
                .font(Typesetter.swiftUIFont(english ? .serif : .mincho, size: 6.5, bold: true))
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(colour, lineWidth: 0.6))
            if english {
                SpineText(house.imprint.englishName.uppercased(), vertical: false, size: 6, bold: true, colour: colour, tracking: 0.6)
                    .frame(height: 48)
            } else {
                SpineText(house.imprint.name, vertical: true, size: 6.5, bold: true, colour: colour)
                    .frame(height: 29)
            }
        }
        .foregroundStyle(colour)
        .padding(.bottom, 5)
    }

    /// The bookshop's paper as its cover has it: the kraft scan, or the paper's colour with its
    /// printed pattern (青海波, 麻の葉) at the cover's scale.
    private var wrapper: some View {
        PaperPattern(style: style, coverWidth: coverWidth)
            .overlay {
                // This copy's paper came from a batch a shade lighter or darker, as its cover says.
                let shade = Look.of(book).shade
                if style.tint == nil && shade != 0 { (shade < 0 ? Color.white : .black).opacity(0.07) }
            }
    }

    /// The scanned grain at the scale it has on this book's cover, so spine and cover are one paper.
    private func paperGrain(_ grain: Print.Grain) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: grain.image), scale: coverScale))
        }
        .allowsHitTesting(false)
    }

    private var coverScale: CGFloat { Print.tileScale(coverWidth: Self.height * 105 / 148) }

    /// The cover art's average colour for the spine, and ink that reads on it.
    static func tone(of image: UIImage) -> (background: Color, text: Color) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let pixel = renderer.image { _ in image.draw(in: CGRect(x: 0, y: 0, width: 1, height: 1)) }
        var r: CGFloat = 0.5, g: CGFloat = 0.5, b: CGFloat = 0.5, a: CGFloat = 1
        if let cg = pixel.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) {
            r = CGFloat(bytes[0]) / 255; g = CGFloat(bytes[1]) / 255; b = CGFloat(bytes[2]) / 255
        }
        let light = 0.299 * r + 0.587 * g + 0.114 * b > 0.6
        return (Color(red: r, green: g, blue: b, opacity: a), light ? Color(hex: "26221D") : Color(hex: "F5F0E4"))
    }
}

/// Spine lettering: a Japanese book's characters stacked down the spine, anything else run down
/// it on its side (top to bottom, as English spines read). Always whole: smaller, never cut.
struct SpineText: View {
    let text: String
    let vertical: Bool
    let size: CGFloat
    let bold: Bool
    /// The ink: a colour, or a gradient for foil.
    let colour: AnyShapeStyle
    var gothic = false
    /// Letter-spacing for lettering run on its side (an English imprint in capitals).
    var tracking: CGFloat = 0

    init<Ink: ShapeStyle>(_ text: String, vertical: Bool, size: CGFloat, bold: Bool, colour: Ink, gothic: Bool = false,
                          tracking: CGFloat = 0) {
        self.text = text
        self.vertical = vertical
        self.size = size
        self.bold = bold
        self.colour = AnyShapeStyle(colour)
        self.gothic = gothic
        self.tracking = tracking
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if vertical {
                let chars = Array(text)
                // One em and a little per character, every character in its own slot.
                let glyph = max(4, min(size, h / (CGFloat(max(chars.count, 1)) * 1.08)))
                VStack(spacing: 0) {
                    ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                        Text(String(ch)).font(font(glyph)).fixedSize()
                            .frame(width: w, height: glyph * 1.08)
                    }
                }
                .foregroundStyle(colour)
                .frame(width: w, height: h, alignment: .top)
            } else {
                // Measured to fit the length of the spine, never cut short.
                Text(text)
                    .font(font(fitted(to: h * 0.98)))
                    .tracking(tracking)
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: h, height: w)
                    .rotationEffect(.degrees(90))
                    .frame(width: w, height: h)
            }
        }
    }

    /// The size that sets the whole of `text` on one line no longer than `length`.
    private func fitted(to length: CGFloat) -> CGFloat {
        let uiFont = gothic ? UIFont.systemFont(ofSize: size, weight: bold ? .heavy : .regular)
                            : Typesetter.font(.serif, size: size, bold: bold)
        let width = (text as NSString).size(withAttributes: [.font: uiFont, .kern: tracking]).width
        return width > length && width > 0 ? size * length / width : size
    }

    private func font(_ points: CGFloat) -> Font {
        if gothic { return .system(size: points, weight: bold ? .heavy : .regular) }
        return Typesetter.swiftUIFont(vertical ? .mincho : .serif, size: points, bold: bold)
    }
}

/// The plank the books stand on.
struct ShelfPlank: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(colors: scheme == .dark ? [Color(hex: "3A2F25"), Color(hex: "241C15")]
                                               : [Color(hex: "C9A97E"), Color(hex: "A88457")],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 12)
            .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.18)).frame(height: 2) }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 3)
            .accessibilityHidden(true)
    }
}

// MARK: The crafted houses

extension BookSpine {
    /// The houses made by a process, each spine printed (or stamped, cut, bound) the way its cover is.
    @ViewBuilder func craftFace(w: CGFloat, h: CGFloat) -> some View {
        let gap = h * 0.02
        let title = { (colour: Color, gothic: Bool) in
            SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: colour, gothic: gothic)
        }
        let byline = { (colour: Color) in
            SpineText(book.author, vertical: japanese, size: w * 0.32, bold: false, colour: colour).frame(height: h * 0.15)
        }
        switch house.imprint {
        case .shimi:
            // Parchment, ruled and set with diamonds at head and foot, as the ornamental frame.
            let brown = Color(hex: "4A3524")
            VStack(spacing: gap) {
                rules(brown, diamond: variant != 2).padding(.top, h * 0.025)
                title(brown, false).frame(maxHeight: .infinity)
                byline(brown)
                shelfCode(brown)
                foot(brown)
                rules(brown, diamond: variant != 2).padding(.bottom, h * 0.02)
            }
            .frame(width: w, height: h).background(Color(hex: ["E9DDC2", "E3D3B1", "EFE6D2"][variant]))
        case .watoji:
            // Stab-bound: the thread passes round the spine at each hole, silk over its corners,
            // and the title is on a pasted slip.
            ZStack {
                colour
                Color.black.opacity(0.12)
                Canvas { ctx, size in
                    for y in [0.12, 0.37, 0.63, 0.88].map({ size.height * $0 }) {
                        var thread = Path()
                        thread.move(to: CGPoint(x: 0, y: y))
                        thread.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(thread.offsetBy(dx: 0, dy: 0.8), with: .color(.black.opacity(0.35)), lineWidth: 1.4)
                        ctx.stroke(thread, with: .color(Color(hex: ["EDE6D4", "B5362A", "D9B65A"][variant])), lineWidth: 1.4)
                    }
                    let k = size.width * 0.5
                    for y in [0, size.height - k] {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: k)), with: .color(Color(hex: "B89A55")))
                    }
                }
                title(ink, false)
                    .padding(.vertical, 5)
                    .frame(width: w * 0.66, height: h * 0.42)
                    .background(Color(hex: "F2ECDD"))
                    .shadow(color: .black.opacity(0.25), radius: 0.8, x: 0.3, y: 0.6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, h * 0.16)
            }
            .frame(width: w, height: h)
        case .kirara:
            // A quiet printed spine under crinkled glassine catching the light.
            ZStack {
                [cream, Color(uiColor: UIColor(hex: house.colour).mixed(with: .white, 0.8)), Color(hex: "FBFAF6")][variant]
                VStack(spacing: gap) {
                    title(ink, false).frame(maxHeight: .infinity).padding(.top, h * 0.05)
                    byline(colour)
                    foot(colour)
                }
                Color.white.opacity(0.3)
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .tiledImage(Image(uiImage: Print.Grain.crinkle.image), scale: coverScale * 0.8))
                }
                .blendMode(.overlay)
                LinearGradient(stops: [.init(color: .white.opacity(0.3), location: 0), .init(color: .clear, location: 0.4),
                                       .init(color: .white.opacity(0.14), location: 0.65), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(width: w, height: h)
            .compositingGroup() // the glassine blends with the cover under it, nothing else
        case .kinu:
            // Dark bookcloth, its weave in it; title, rules and colophon stamped in gold foil.
            let foils = [["9C7A2E", "E9D58E", "B8933F", "F3E6B0", "8E6E28"], ["7D8086", "E6E8EB", "A5A9AF", "F5F6F7", "6E7177"],
                         ["8A4B2C", "E3A07A", "A8623E", "F0C3A4", "7A3F24"]]
            let gold = LinearGradient(colors: foils[variant].map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
            ZStack {
                colour
                Color.black.opacity(0.58)
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: coverScale * 0.5))
                }
                .blendMode(.softLight)
                VStack(spacing: gap) {
                    gold.frame(height: 1).padding(.top, h * 0.04)
                    SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: gold).frame(maxHeight: .infinity)
                    SpineText(book.author, vertical: japanese, size: w * 0.32, bold: false, colour: gold).frame(height: h * 0.15)
                    Text(house.imprint.colophon(english: english))
                        .font(Typesetter.swiftUIFont(english ? .serif : .mincho, size: 7, bold: true))
                        .foregroundStyle(gold)
                        .frame(width: 12, height: 12)
                    gold.frame(height: 1).padding(.bottom, h * 0.04)
                }
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0.3, y: 0.6)
            }
            .frame(width: w, height: h)
            .compositingGroup() // the weave blends with the cloth, nothing else
        case .shimo:
            // Pale paper; the title has no ink, only relief.
            let paper = Color(uiColor: UIColor(hex: house.colour).mixed(with: .white, [0.72, 0.6, 0.83][variant]))
            VStack(spacing: gap) {
                ZStack {
                    title(.white.opacity(0.55), false).offset(x: -0.4, y: -0.4)
                    title(.black.opacity(0.24), false).offset(x: 0.4, y: 0.5).blur(radius: 0.3)
                    title(paper, false)
                }
                .frame(maxHeight: .infinity).padding(.top, h * 0.05)
                byline(colour.opacity(0.85))
                foot(colour.opacity(0.85))
            }
            .frame(width: w, height: h).background(paper)
        case .nichirin:
            // The halftone sun, screened in the author's colour, at the head.
            VStack(spacing: gap) {
                Canvas { ctx, size in
                    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = size.width * 0.48 * [1, 0.82, 1.15][variant]
                    let pitch = max(2, coverWidth * [0.016, 0.013, 0.021][variant])
                    let n = Int(radius * 1.5 / pitch)
                    var dots = Path()
                    for i in -n...n {
                        for j in -n...n {
                            let u = CGFloat(i) * pitch, v = CGFloat(j) * pitch
                            let p = CGPoint(x: centre.x + (u - v) * 0.7071, y: centre.y + (u + v) * 0.7071)
                            let fall = 1 - hypot(p.x - centre.x, p.y - centre.y) / radius
                            guard fall > 0 else { continue }
                            let r = pitch * 0.55 * pow(fall, 0.45)
                            dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        }
                    }
                    ctx.fill(dots, with: .color(colour))
                }
                .frame(width: w, height: w).padding(.top, h * 0.03)
                title(ink, false).frame(maxHeight: .infinity)
                byline(colour)
                foot(ink)
            }
            .frame(width: w, height: h).background(cream)
        case .choyo:
            // Two inks overprinted at the head, the second plate a hair out of register.
            let second = Color(hex: house.colour == "9A6A22" ? "2F6F8F" : "D9A62E")
            VStack(spacing: gap) {
                ZStack {
                    switch variant {
                    case 0:
                        Circle().fill(colour).frame(width: w * 0.8, height: w * 0.8).offset(y: -w * 0.12)
                        Rectangle().fill(second).frame(width: w * 0.62, height: w * 0.62).offset(x: w * 0.12 + 0.7, y: w * 0.18 + 0.5)
                            .blendMode(.multiply)
                    case 1:
                        Circle().fill(colour).frame(width: w * 0.66, height: w * 0.66).offset(x: -w * 0.1, y: -w * 0.14)
                        Circle().fill(second).frame(width: w * 0.66, height: w * 0.66).offset(x: w * 0.12 + 0.7, y: w * 0.16 + 0.5)
                            .blendMode(.multiply)
                    default:
                        Rectangle().fill(colour).frame(width: w * 0.8, height: w * 0.42).offset(y: -w * 0.2)
                        Triangle().fill(second).frame(width: w * 0.66, height: w * 0.62).offset(x: 0.7, y: w * 0.16 + 0.5)
                            .blendMode(.multiply)
                    }
                }
                .compositingGroup()
                .frame(width: w, height: w * 1.15).clipped().padding(.top, h * 0.03)
                title(ink, false).frame(maxHeight: .infinity)
                byline(colour)
                foot(ink)
            }
            .frame(width: w, height: h).background(cream)
        case .kodama:
            // A woodcut block, its grain in the ink and its edges rough, the title cut out of it.
            let inverted = variant == 2
            VStack(spacing: gap) {
                ZStack {
                    inverted ? cream : colour
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: coverScale * 1.6))
                    }
                    .blendMode(.overlay)
                    title(inverted ? colour : cream, false).padding(.vertical, 6)
                }
                .compositingGroup()
                .clipShape(RoughRect(seed: book.id))
                .padding(3)
                .frame(maxHeight: .infinity)
                byline(inverted ? cream : colour)
                foot(inverted ? cream : colour)
            }
            .frame(width: w, height: h).background(inverted ? colour : cream)
        case .namari:
            // Letterpress: rules at head and foot, the type bitten in, light under each impression.
            VStack(spacing: gap) {
                rules(colour, diamond: false).padding(.top, h * 0.03)
                ZStack {
                    title(.white.opacity(0.8), false).offset(y: 0.5)
                    title(ink, false)
                }
                .frame(maxHeight: .infinity)
                Text(["◇", "❖", "※"][variant]).font(.system(size: 6)).foregroundStyle(colour)
                byline(ink)
                shelfCode(ink)
                foot(ink)
                rules(colour, diamond: false).padding(.bottom, h * 0.02)
            }
            .frame(width: w, height: h).background(Color(hex: "F2EDE1"))
        case .aizome:
            // Indigo shibori: pale resist rings where the cloth was bound, the title on a pasted slip.
            ZStack {
                Color(hex: ["203556", "1A2A44", "2C4870"][variant])
                Canvas { ctx, size in
                    var rng = SeededRandom(string: book.id + "shibori")
                    var y: CGFloat = 6
                    while y < size.height {
                        let x = size.width * CGFloat.random(in: 0.25...0.75, using: &rng), r = size.width * CGFloat.random(in: 0.18...0.32, using: &rng)
                        for k in 0..<3 {
                            let rr = r * (1 - CGFloat(k) * 0.3)
                            ctx.stroke(Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)),
                                       with: .color(Color(hex: "E3EAF2").opacity(.random(in: 0.45...0.75, using: &rng))), lineWidth: 0.9)
                        }
                        y += r * 2.6
                    }
                }
                VStack(spacing: gap) {
                    title(ink, false)
                        .padding(.vertical, 5)
                        .frame(width: w * 0.7, height: h * 0.5)
                        .background(Color(hex: "F3EEE2"))
                        .shadow(color: .black.opacity(0.3), radius: 0.8, x: 0.3, y: 0.6)
                        .padding(.top, h * 0.06)
                    Spacer(minLength: 0)
                    foot(Color(hex: "E3EAF2"))
                }
            }
            .frame(width: w, height: h)
        default:
            VStack(spacing: gap) {
                Rectangle().fill(colour).frame(height: h * 0.035)
                title(ink, false).frame(maxHeight: .infinity)
                byline(colour)
                shelfCode(colour)
                foot(colour)
            }
            .frame(width: w, height: h).background(cream)
        }
    }

    /// A thick and a thin rule, as the printed frames and letterpress title pages have them.
    private func rules(_ colour: Color, diamond: Bool) -> some View {
        VStack(spacing: 1.5) {
            Rectangle().fill(colour).frame(height: 1.2)
            if diamond { Text("◆").font(.system(size: 4)).foregroundStyle(colour) }
            Rectangle().fill(colour).frame(height: 0.5)
        }
        .padding(.horizontal, 3)
    }
}
