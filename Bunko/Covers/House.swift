import SwiftUI

/// A publisher's house style, for a book with no paper cover and no cover art of its own: the
/// way a bunko shelf is a row of imprints, each with its own look. The imprint is picked by the
/// book, the colour by the author (as some houses give each author theirs), and every book gets
/// its shelf code (や 5 51: the author's initial kana, the author's number, the book's) and price.
struct House: Equatable {
    enum Imprint: CaseIterable {
        /// White, a band of the author's colour across the head carrying the title.
        case shirasagi
        /// The author's colour all over, the title in a double frame.
        case tsukikage
        /// White, a stripe down the spine side with the imprint's name.
        case seirin
        /// Arrow feathers (矢絣) over the head, a white label for the title.
        case chidori
        /// Bold gothic on colour, ranged to the fore-edge.
        case todai

        var name: String {
            switch self {
            case .shirasagi: "白鷺文庫"
            case .tsukikage: "月影文庫"
            case .seirin: "青林文庫"
            case .chidori: "千鳥文庫"
            case .todai: "灯台文庫"
            }
        }

        /// The house's printed mark at the foot of a cover: one character in a ring.
        var colophon: String {
            switch self {
            case .shirasagi: "鷺"
            case .tsukikage: "月"
            case .seirin: "林"
            case .chidori: "鳥"
            case .todai: "灯"
            }
        }

        /// A symbol for the house, where a printed mark would be too small (the spine).
        var mark: String {
            switch self {
            case .shirasagi: "bird.fill"
            case .tsukikage: "moon.fill"
            case .seirin: "leaf.fill"
            case .chidori: "water.waves"
            case .todai: "light.beacon.max.fill"
            }
        }
    }

    static let authorColours = ["8E2F2A", "2F4F7F", "3F6B4A", "9A6A22", "5B3F73", "2E2B28", "A84E64", "3E6F78"]

    var imprint: Imprint
    var colour: String
    var shelfCode: String
    var price: Int

    static func of(_ book: Book) -> House {
        let author = book.author.trimmingCharacters(in: .whitespaces)
        // A series shares its house and colour; its volumes are numbered in the shelf code.
        let byDesign = hash(book.designKey), byBook = hash(book.id)
        let byAuthor = hash(book.volume?.series ?? (author.isEmpty ? book.title : author))
        let number = book.volume?.index.map { Int($0) } ?? byBook % 40 + 1
        return House(imprint: Imprint.allCases[byDesign % Imprint.allCases.count],
                     colour: authorColours[byAuthor % authorColours.count],
                     shelfCode: "\(initial(of: author.isEmpty ? book.title : author)) \(byAuthor % 60 + 1) \(number)",
                     price: 400 + hash(book.id + "¥") % 50 * 10)
    }

    /// The shelf code's kana: the reading's first sound for a Japanese name (夏目漱石 → な), the
    /// surname's initial otherwise (Lewis Carroll → C).
    static func initial(of name: String) -> String {
        let japanese = name.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        if japanese {
            let reading = kana(name)
            return String(reading.first ?? name.first ?? "?")
        }
        let surname = name.split(separator: " ").last.map(String.init) ?? name
        return surname.first.map { String($0).uppercased() } ?? "?"
    }

    /// A Japanese name read aloud, in hiragana, by the system's tokenizer.
    private static func kana(_ name: String) -> String {
        let text = name as CFString
        let tokenizer = CFStringTokenizerCreate(nil, text, CFRange(location: 0, length: CFStringGetLength(text)),
                                                kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
        var latin = ""
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            if let word = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                latin += word
            }
        }
        let hiragana = latin.applyingTransform(.latinToHiragana, reverse: false) ?? ""
        return hiragana.isEmpty ? name : hiragana
    }

    private static func hash(_ text: String) -> Int {
        text.unicodeScalars.reduce(5381) { ($0 &* 33 &+ Int($1.value)) & 0x7FFFFFFF }
    }
}

/// A book in its publisher's own cover, in its house's style.
struct HouseCover: View {
    let book: Book
    var large = false

    private var house: House { .of(book) }
    private var vertical: Bool { book.rightToLeft }
    private var colour: Color { Color(hex: house.colour) }
    private var cream: Color { Color(hex: "F5F0E4") }
    private var ink: Color { Color(hex: "26221D") }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                face(w: w, h: h)
                Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile).blendMode(.multiply).opacity(0.5)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityElement()
        .accessibilityLabel("\(book.title), \(book.author), \(house.imprint.name)")
    }

    @ViewBuilder private func face(w: CGFloat, h: CGFloat) -> some View {
        switch house.imprint {
        case .shirasagi:
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    colour
                    title(cream, width: w * 0.8, height: h * 0.42, size: w * 0.11)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    shelfCode(cream, w: w).padding(w * 0.04)
                }
                .frame(height: h * 0.52)
                author(colour, w: w).padding(.top, h * 0.05)
                Spacer()
                foot(colour, w: w)
            }
            .background(cream)
        case .tsukikage:
            ZStack {
                colour
                Rectangle().stroke(cream.opacity(0.8), lineWidth: max(0.5, w * 0.006)).padding(w * 0.05)
                Rectangle().stroke(cream.opacity(0.8), lineWidth: max(0.5, w * 0.003)).padding(w * 0.068)
                VStack(spacing: h * 0.03) {
                    shelfCode(cream, w: w).frame(maxWidth: .infinity, alignment: vertical ? .leading : .trailing)
                    title(cream, width: w * 0.7, height: h * 0.42, size: w * 0.105)
                    author(cream.opacity(0.85), w: w)
                    Spacer()
                    foot(cream, w: w)
                }
                .padding(w * 0.11)
            }
        case .seirin:
            HStack(spacing: 0) {
                if !vertical { stripe(w: w) }
                VStack(spacing: h * 0.03) {
                    shelfCode(colour, w: w).frame(maxWidth: .infinity, alignment: vertical ? .leading : .trailing)
                    title(ink, width: w * 0.66, height: h * 0.48, size: w * 0.11)
                    author(colour, w: w)
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(w * 0.07)
                if vertical { stripe(w: w) }
            }
            .background(cream)
        case .chidori:
            VStack(spacing: 0) {
                ZStack {
                    Canvas { ctx, size in
                        // 矢絣: columns of arrow feathers, each column half a feather down from the last.
                        let c = w * 0.14, r = c * 1.1
                        var feathers = Path()
                        for i in 0...Int(size.width / c) + 1 {
                            let x = CGFloat(i) * c
                            var y = (i.isMultiple(of: 2) ? 0 : -r / 2) - r
                            while y < size.height + r {
                                feathers.addLines([CGPoint(x: x, y: y), CGPoint(x: x + c / 2, y: y + r * 0.42),
                                                   CGPoint(x: x + c, y: y), CGPoint(x: x + c, y: y + r * 0.5),
                                                   CGPoint(x: x + c / 2, y: y + r * 0.92), CGPoint(x: x, y: y + r * 0.5)])
                                feathers.closeSubpath()
                                y += r
                            }
                        }
                        ctx.fill(feathers, with: .color(colour))
                    }
                    .background(cream)
                    title(ink, width: w * 0.62, height: h * 0.38, size: w * 0.1)
                        .padding(w * 0.05)
                        .background(cream)
                        .overlay(Rectangle().stroke(colour, lineWidth: max(0.5, w * 0.008)))
                }
                .frame(height: h * 0.6)
                .clipped()
                author(colour, w: w).padding(.top, h * 0.05)
                shelfCode(colour, w: w).padding(.top, h * 0.02)
                Spacer()
                foot(colour, w: w)
            }
            .background(cream)
        case .todai:
            ZStack {
                colour
                VStack(alignment: vertical ? .trailing : .leading, spacing: h * 0.03) {
                    shelfCode(cream, w: w)
                    Text(book.title)
                        .font(.system(size: w * 0.13, weight: .black))
                        .foregroundStyle(cream)
                        .multilineTextAlignment(vertical ? .trailing : .leading)
                        .minimumScaleFactor(0.3)
                        .lineLimit(5)
                    Rectangle().fill(cream).frame(width: w * 0.25, height: max(0.5, w * 0.012))
                    author(cream.opacity(0.85), w: w, gothic: true)
                    Spacer()
                    foot(cream, w: w)
                }
                .frame(maxWidth: .infinity, alignment: vertical ? .trailing : .leading)
                .padding(w * 0.09)
            }
        }
    }

    // MARK: Parts

    /// The title, whole: vertical for a right-bound book (shrunk, then two columns), else wrapped.
    @ViewBuilder private func title(_ color: Color, width: CGFloat, height: CGFloat, size: CGFloat) -> some View {
        if vertical {
            let chars = Array(book.title)
            let (columns, glyph) = PaperCover.verticalSlip(count: chars.count, base: size, height: height)
            let perColumn = (chars.count + columns - 1) / columns
            // One em and a little per character, as the slip sets them; columns right to left.
            HStack(alignment: .top, spacing: glyph * 0.15) {
                ForEach((0..<columns).reversed(), id: \.self) { c in
                    VStack(spacing: 0) {
                        ForEach(Array(chars.dropFirst(c * perColumn).prefix(perColumn).enumerated()), id: \.offset) { _, ch in
                            Text(String(ch)).font(Typesetter.swiftUIFont(.mincho, size: glyph, bold: true))
                                .frame(width: glyph * 1.1, height: glyph * 1.08)
                        }
                    }
                }
            }
            .foregroundStyle(color)
            .frame(width: min(width, glyph * (1.25 * CGFloat(columns) + 0.3)), height: height)
        } else {
            Text(book.title)
                .font(Typesetter.swiftUIFont(.serif, size: size, bold: true))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.3)
                .lineLimit(5)
                .frame(width: width, height: height)
        }
    }

    /// The author, and the series and volume when the title doesn't carry them.
    private func author(_ color: Color, w: CGFloat, gothic: Bool = false) -> some View {
        let series = book.series.flatMap { name in book.volume?.index.map { "\(name) \(Book.Volume.label($0))" } ?? name }
        return Text([book.author, series ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
            .font(gothic ? .system(size: w * 0.055, weight: .bold)
                         : Typesetter.swiftUIFont(vertical ? .mincho : .serif, size: w * 0.06))
            .tracking(w * 0.005)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, w * 0.06)
    }

    /// や 5 51: the initial boxed, then the numbers.
    private func shelfCode(_ color: Color, w: CGFloat) -> some View {
        let parts = house.shelfCode.split(separator: " ").map(String.init)
        return HStack(spacing: w * 0.012) {
            Text(parts.first ?? "")
                .font(.system(size: w * 0.045, weight: .bold))
                .padding(.horizontal, w * 0.01)
                .overlay(Rectangle().stroke(color, lineWidth: max(0.5, w * 0.004)))
            Text(parts.dropFirst().joined(separator: " ")).font(.system(size: w * 0.04, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(color)
        .lineLimit(1)
    }

    /// The house mark and name.
    private func foot(_ color: Color, w: CGFloat) -> some View {
        VStack(spacing: w * 0.015) {
            Text(house.imprint.colophon)
                .font(Typesetter.swiftUIFont(.mincho, size: w * 0.05, bold: true))
                .frame(width: w * 0.085, height: w * 0.085)
                .overlay(Circle().stroke(color, lineWidth: max(0.5, w * 0.005)))
            Text(house.imprint.name).font(Typesetter.swiftUIFont(.mincho, size: w * 0.042, bold: true)).tracking(w * 0.012)
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.bottom, w * 0.06)
    }

    /// 青林's stripe down the spine side, its name set vertically in it.
    private func stripe(w: CGFloat) -> some View {
        VStack(spacing: w * 0.01) {
            ForEach(Array(house.imprint.name.enumerated()), id: \.offset) { _, ch in
                Text(String(ch)).font(Typesetter.swiftUIFont(.mincho, size: w * 0.06, bold: true))
            }
        }
        .foregroundStyle(cream)
        .padding(.top, w * 0.1)
        .frame(width: w * 0.14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(colour)
    }
}
