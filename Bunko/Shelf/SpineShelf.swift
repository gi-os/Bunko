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

    private var japanese: Bool { book.rightToLeft && !book.rowsRightToLeft }
    private var house: House { .of(book) }
    private var colour: Color { Color(hex: house.colour) }
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
                    .padding(.vertical, h * 0.03).frame(maxHeight: .infinity).frame(width: w).background(colour)
                author(colour, false)
                shelfCode(colour)
                foot(colour)
            }
            .frame(width: w, height: h).background(cream)
        case .tsukikage:
            VStack(spacing: gap) {
                Rectangle().fill(cream.opacity(0.8)).frame(height: 0.8).padding(.top, h * 0.03)
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: cream).frame(maxHeight: .infinity)
                author(cream.opacity(0.85), false)
                shelfCode(cream)
                foot(cream)
            }
            .frame(width: w, height: h).background(colour)
        case .seirin:
            VStack(spacing: gap) {
                Rectangle().fill(colour).frame(height: h * 0.035)
                SpineText(book.title, vertical: japanese, size: w * 0.5, bold: true, colour: ink).frame(maxHeight: .infinity)
                author(colour, false)
                foot(cream).padding(.top, 3).frame(maxWidth: .infinity).background(colour)
            }
            .frame(width: w, height: h).background(cream)
        case .chidori:
            VStack(spacing: gap) {
                // 矢絣, as the cover prints it.
                ArrowFeathers(column: w / 3).fill(colour).frame(height: h * 0.1).clipped()
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

    /// The house's colophon, its kanji printed in a ring, and its name, as the covers carry them.
    private func foot(_ colour: Color) -> some View {
        VStack(spacing: 2) {
            Text(house.imprint.colophon)
                .font(Typesetter.swiftUIFont(.mincho, size: 6.5, bold: true))
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(colour, lineWidth: 0.6))
            SpineText(house.imprint.name, vertical: true, size: 6.5, bold: true, colour: colour)
                .frame(height: 29)
        }
        .foregroundStyle(colour)
        .padding(.bottom, 5)
    }

    /// The bookshop's paper: kraft is the scan of the real thing, the rest their colour.
    @ViewBuilder private var wrapper: some View {
        if style.paper == .kraft && style.tint == nil {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .tiledImage(Image(uiImage: Print.kraft), scale: coverScale))
            }
        } else {
            Color(hex: style.baseHex)
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
    let colour: Color
    var gothic = false

    init(_ text: String, vertical: Bool, size: CGFloat, bold: Bool, colour: Color, gothic: Bool = false) {
        self.text = text
        self.vertical = vertical
        self.size = size
        self.bold = bold
        self.colour = colour
        self.gothic = gothic
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
                Text(text)
                    .font(font(size))
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(width: h, height: w)
                    .rotationEffect(.degrees(90))
                    .frame(width: w, height: h)
            }
        }
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
