import SwiftUI

/// A book in one of the English houses' covers, printed the way that house prints: bands, cloth
/// and foil, patterned boards, marbling, letterpress, linocut, engraving, overprint, halftone,
/// screen print, pulp, deckle, deco, Swiss or riso. Three compositions per technique (one per
/// house) and three layouts per house (`House.variant`).
struct EnglishCover: View {
    let book: Book
    let house: House
    let edition: EnglishHouse

    var v: Int { house.variant % 3 }
    var colour: Color { Color(hex: house.colour) }
    var second: Color { Color(hex: EnglishHouse.second(to: house.colour, variant: house.variant)) }
    var stock: Color { Color(hex: edition.stock) }
    /// The ink type is set in: the house's own, or the book's colour.
    var ink: Color { Color(hex: edition.ink ?? house.colour) }
    var dark: Color { Color(hex: edition.ink ?? "26221D") }
    var face: EnglishHouse.Face { edition.face }
    /// Small type (byline, imprint, number) in a face that stays legible small.
    var small: EnglishHouse.Face { edition.face == .script ? .baskerville : edition.face }
    var foil: LinearGradient { LinearGradient(colors: edition.foil.colours, startPoint: .topLeading, endPoint: .bottomTrailing) }

    func shade(_ hex: String, _ toward: UIColor, _ amount: CGFloat) -> Color {
        Color(uiColor: UIColor(hex: hex).mixed(with: toward, amount))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            face(w: w, h: h)
                .frame(width: w, height: h)
                .clipped()
        }
        .accessibilityElement()
        .accessibilityLabel("\(book.title), \(book.author), \(edition.name)")
    }

    @ViewBuilder private func face(w: CGFloat, h: CGFloat) -> some View {
        switch edition.technique {
        case .bands: bands(w: w, h: h)
        case .cloth: cloth(w: w, h: h)
        case .boards: boards(w: w, h: h)
        case .marbled: marbled(w: w, h: h)
        case .letterpress: letterpress(w: w, h: h)
        case .linocut: linocut(w: w, h: h)
        case .engraving: engraving(w: w, h: h)
        case .overprint: overprint(w: w, h: h)
        case .halftone: halftone(w: w, h: h)
        case .screenprint: screenprint(w: w, h: h)
        case .pulp: pulp(w: w, h: h)
        case .deckle: deckle(w: w, h: h)
        case .deco: deco(w: w, h: h)
        case .swiss: swiss(w: w, h: h)
        case .riso: riso(w: w, h: h)
        }
    }

    // MARK: Type

    func title(_ colour: Color, size: CGFloat, width: CGFloat, height: CGFloat, align: TextAlignment = .center,
               caps: Bool = false, bold: Bool = true, tracking: CGFloat = 0) -> some View {
        Text(caps ? book.title.uppercased() : book.title)
            .font(face.font(size: size, bold: bold))
            .tracking(tracking)
            .foregroundStyle(colour)
            .multilineTextAlignment(align)
            .lineLimit(6)
            .minimumScaleFactor(0.25)
            .frame(width: width, height: height, alignment: align == .leading ? .bottomLeading : .center)
    }

    /// The author, and the series and number when the title doesn't carry them.
    var bylineText: String {
        let series = book.series.flatMap { name in book.volume?.index.map { "\(name) \(Book.Volume.label($0))" } ?? name }
        return [book.author, series ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func byline(_ colour: Color, size: CGFloat, italic: Bool = false, caps: Bool = false, tracking: CGFloat = 0) -> some View {
        Text(caps ? bylineText.uppercased() : bylineText)
            .font(small.font(size: size))
            .italic(italic)
            .tracking(tracking)
            .foregroundStyle(colour)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    /// The house's mark in its ring, its name in tracked capitals, and the catalogue number.
    func foot(_ colour: Color, w: CGFloat, alignment: HorizontalAlignment = .center, number: Bool = true) -> some View {
        VStack(alignment: alignment, spacing: w * 0.012) {
            Text(edition.colophon)
                .font(small.font(size: w * (edition.colophon.count > 1 ? 0.034 : 0.045), bold: true))
                .frame(width: w * 0.085, height: w * 0.085)
                .overlay(Circle().stroke(colour, lineWidth: max(0.5, w * 0.005)))
            Text(edition.name.uppercased()).font(small.font(size: w * 0.03, bold: true)).tracking(w * 0.006)
            if number { Text(house.catalogue).font(small.font(size: w * 0.026)).opacity(0.75) }
        }
        .foregroundStyle(colour)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    func rule(_ colour: Color, w: CGFloat, width: CGFloat? = nil) -> some View {
        let r = edition.rules
        return VStack(spacing: w * 0.012) {
            Rectangle().fill(colour).frame(height: max(0.5, w * (r == .heavy ? 0.014 : 0.005)))
            if r == .double || r == .heavy { Rectangle().fill(colour).frame(height: max(0.5, w * 0.004)) }
        }
        .frame(width: width)
        .opacity(r == .none ? 0 : 1)
    }

    /// A printer's ornament, never an emoji.
    func ornament(_ glyph: String?) -> String { (glyph ?? "❦") + "\u{FE0E}" }

    // MARK: Bands

    @ViewBuilder func bands(w: CGFloat, h: CGFloat) -> some View {
        switch edition.composition {
        case 0:
            // Colour, white, colour: the publisher's name in the top band, its mark in the bottom.
            let band = h * [0.28, 0.22, 0.33][v]
            VStack(spacing: 0) {
                ZStack {
                    colour
                    Text(edition.name.uppercased()).font(face.font(size: w * 0.045, bold: true)).tracking(w * 0.012)
                        .foregroundStyle(stock).lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, w * 0.08)
                }
                .frame(height: band)
                ZStack {
                    stock
                    VStack(spacing: h * 0.025) {
                        title(dark, size: w * 0.105, width: w * 0.82, height: h - band * 2 - h * 0.14)
                        Rectangle().fill(colour).frame(width: w * 0.18, height: max(0.6, w * 0.006))
                        byline(dark, size: w * 0.05)
                    }
                    .padding(.horizontal, w * 0.06)
                }
                ZStack {
                    colour
                    if v == 1 { Rectangle().fill(stock).frame(height: max(0.5, w * 0.004)).frame(maxHeight: .infinity, alignment: .top).padding(.top, w * 0.02) }
                    foot(stock, w: w)
                }
                .frame(height: band)
            }
        case 1:
            // One band across a pale cover, ruled above and below.
            let top = h * [0.3, 0.38, 0.24][v]
            ZStack(alignment: .top) {
                stock
                VStack(spacing: h * 0.02) {
                    Text(edition.name.uppercased()).font(face.font(size: w * 0.036, bold: true)).tracking(w * 0.01)
                        .foregroundStyle(colour).padding(.top, h * 0.07)
                    rule(colour, w: w, width: w * 0.8)
                }
                VStack(spacing: h * 0.03) {
                    rule(colour, w: w, width: w * 0.8)
                    ZStack {
                        colour
                        title(stock, size: w * 0.1, width: w * 0.8, height: h * 0.24)
                    }
                    .frame(height: h * 0.3)
                    rule(colour, w: w, width: w * 0.8)
                    byline(colour, size: w * 0.05)
                }
                .padding(.top, top)
                foot(colour, w: w).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, h * 0.05)
            }
        default:
            // A colour border round a pale panel.
            let inset = w * [0.07, 0.09, 0.06][v]
            ZStack {
                colour
                ZStack {
                    RoundedRectangle(cornerRadius: v == 2 ? w * 0.05 : 0).fill(stock)
                    if v == 1 { Rectangle().stroke(colour, lineWidth: max(0.5, w * 0.004)).padding(w * 0.025) }
                    VStack(spacing: h * 0.03) {
                        Text(edition.name.uppercased()).font(face.font(size: w * 0.032)).tracking(w * 0.012).foregroundStyle(colour)
                        Spacer(minLength: 0)
                        title(dark, size: w * 0.1, width: w * 0.7, height: h * 0.4)
                        byline(colour, size: w * 0.048, italic: true)
                        Spacer(minLength: 0)
                        foot(colour, w: w)
                    }
                    .padding(.vertical, h * 0.05)
                }
                .padding(inset)
            }
        }
    }

    // MARK: Cloth and foil

    func clothWeave(_ ground: Color) -> some View {
        ZStack {
            ground
            Canvas { ctx, size in
                let scale = Print.tileScale(coverWidth: size.width) * 0.45
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: scale))
                var across = ctx
                across.opacity = 0.55
                across.rotate(by: .degrees(90))
                across.fill(Path(CGRect(x: 0, y: -size.width, width: size.height, height: size.width)),
                            with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: scale))
            }
            .blendMode(.softLight)
        }
    }

    func foilText(_ text: String, font: Font, width: CGFloat, height: CGFloat, align: TextAlignment = .center) -> some View {
        foil.mask(Text(text).font(font).multilineTextAlignment(align).lineLimit(5).minimumScaleFactor(0.3)
            .frame(width: width, height: height))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.5), radius: 0, x: 0.4, y: 0.7)
    }

    @ViewBuilder func cloth(w: CGFloat, h: CGFloat) -> some View {
        switch edition.composition {
        case 0:
            // Dark cloth, a blind-stamped panel, the title in foil.
            let ground = shade(house.colour, .black, 0.5)
            ZStack {
                clothWeave(ground)
                let panel = RoundedRectangle(cornerRadius: v == 2 ? w * 0.06 : 0)
                panel.stroke(Color.black.opacity(0.45), lineWidth: max(1, w * 0.008)).padding(w * 0.09)
                panel.stroke(Color.white.opacity(0.12), lineWidth: max(0.5, w * 0.004)).padding(w * 0.09).offset(x: 0.6, y: 0.8)
                if v == 1 { Rectangle().stroke(Color.black.opacity(0.35), lineWidth: max(0.5, w * 0.004)).padding(w * 0.12) }
                VStack(spacing: h * 0.03) {
                    Spacer()
                    foilText(book.title, font: face.font(size: w * 0.1, bold: true), width: w * 0.66, height: h * 0.34)
                    foilText(ornament(edition.ornament), font: .system(size: w * 0.06), width: w * 0.2, height: w * 0.08)
                    foilText(bylineText, font: face.font(size: w * 0.05), width: w * 0.66, height: w * 0.07)
                    Spacer()
                    foilText(edition.colophon, font: face.font(size: w * 0.05, bold: true), width: w * 0.2, height: w * 0.08)
                        .padding(.bottom, h * 0.1)
                }
            }
        case 1:
            // Natural linen with a printed paper label pasted on.
            let y = h * [0.12, 0.26, 0.06][v]
            ZStack(alignment: .top) {
                clothWeave(stock)
                VStack(spacing: h * 0.018) {
                    title(dark, size: w * 0.085, width: w * 0.56, height: h * 0.2)
                    Rectangle().fill(colour).frame(width: w * 0.12, height: max(0.5, w * 0.004))
                    byline(colour, size: w * 0.042, italic: true)
                }
                .padding(w * 0.045)
                .background(Color(hex: "F6F1E4"))
                .overlay(Rectangle().stroke(colour, lineWidth: max(0.5, w * 0.005)).padding(w * 0.015))
                .rotationEffect(.degrees(v == 2 ? -0.8 : 0.4))
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0.4, y: 0.9)
                .padding(.top, y)
                foot(Color(hex: "3B342C").opacity(0.7), w: w).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, h * 0.06)
            }
        default:
            // Coloured cloth, bands of gilt rules at head and foot, the title in foil.
            let ground = shade(house.colour, .black, 0.22)
            let gilt = VStack(spacing: w * 0.012) {
                foil.frame(height: max(1, w * 0.012))
                foil.frame(height: max(0.5, w * 0.004))
                foil.frame(height: max(0.5, w * 0.004))
            }
            ZStack {
                clothWeave(ground)
                VStack(spacing: 0) {
                    gilt.padding(.top, h * [0.08, 0.14, 0.05][v])
                    Spacer()
                    foilText(book.title, font: face.font(size: w * 0.11, bold: true), width: w * 0.74, height: h * 0.36)
                    foilText(ornament(edition.ornament), font: .system(size: w * 0.05), width: w * 0.2, height: w * 0.07)
                    foilText(bylineText, font: face.font(size: w * 0.048), width: w * 0.7, height: w * 0.07)
                    Spacer()
                    gilt.rotationEffect(.degrees(180)).padding(.bottom, h * [0.08, 0.14, 0.05][v])
                }
            }
        }
    }

    // MARK: Patterned boards

    func label(w: CGFloat, h: CGFloat, oval: Bool = false) -> some View {
        VStack(spacing: h * 0.014) {
            title(dark, size: w * 0.085, width: w * (oval ? 0.5 : 0.56), height: h * 0.17)
            Text(ornament(edition.ornament)).font(.system(size: w * 0.035)).foregroundStyle(colour)
            byline(dark.opacity(0.8), size: w * 0.04, italic: true)
            Text(edition.name.uppercased()).font(face.font(size: w * 0.025)).tracking(w * 0.008).foregroundStyle(colour)
        }
        .padding(.horizontal, w * (oval ? 0.1 : 0.05))
        .padding(.vertical, h * (oval ? 0.05 : 0.03))
        .background(oval ? AnyShape(Ellipse()).fill(Color(hex: "F7F2E6")) : AnyShape(Rectangle()).fill(Color(hex: "F7F2E6")))
        .overlay((oval ? AnyShape(Ellipse()) : AnyShape(Rectangle())).stroke(colour, lineWidth: max(0.5, w * 0.004)).padding(w * 0.014))
        .shadow(color: .black.opacity(0.2), radius: 0.8, x: 0.3, y: 0.8)
    }

    @ViewBuilder func boards(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Group {
                switch edition.composition {
                case 0: boardGlyphs(w: w)
                case 1: boardStripes(w: w)
                default: boardLattice(w: w)
                }
            }
            label(w: w, h: h, oval: edition.composition == 1).padding(.top, h * [0.12, 0.2, 0.08][v])
        }
    }

    func boardGlyphs(w: CGFloat) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stock))
            let step = w * [0.11, 0.08, 0.14][v]
            var glyph = ctx.resolve(Text(ornament(edition.ornament)).font(.system(size: step * 0.62)))
            glyph.shading = .color(colour)
            var alt = ctx.resolve(Text(ornament(edition.ornament)).font(.system(size: step * 0.62)))
            alt.shading = .color(v == 2 ? second : colour)
            var row = 0
            var y = step * 0.5
            while y < size.height + step {
                var x = (row.isMultiple(of: 2) ? 0 : step / 2) + step * 0.25
                while x < size.width + step {
                    ctx.draw(row.isMultiple(of: 2) ? glyph : alt, at: CGPoint(x: x, y: y))
                    x += step
                }
                y += step * 0.8
                row += 1
            }
        }
    }

    func boardStripes(w: CGFloat) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stock))
            let wide = w * [0.07, 0.045, 0.1][v]
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: wide, height: size.height)), with: .color(colour))
                if v == 1 {
                    ctx.fill(Path(CGRect(x: x + wide * 1.45, y: 0, width: max(0.6, w * 0.006), height: size.height)), with: .color(second))
                }
                x += wide * 2
                i += 1
            }
        }
    }

    func boardLattice(w: CGFloat) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stock))
            let step = w * [0.12, 0.09, 0.16][v]
            var lines = Path()
            var x = -size.height
            while x < size.width + size.height {
                lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x + size.height, y: size.height))
                lines.move(to: CGPoint(x: x + size.height, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            ctx.stroke(lines, with: .color(colour), lineWidth: max(0.5, w * 0.006))
            var dots = Path()
            var y: CGFloat = 0
            var row = 0
            while y < size.height + step {
                var dx = row.isMultiple(of: 2) ? 0 : step / 2
                while dx < size.width + step {
                    let r = w * 0.012
                    dots.addEllipse(in: CGRect(x: dx - r, y: y - r, width: r * 2, height: r * 2))
                    dx += step
                }
                y += step / 2
                row += 1
            }
            ctx.fill(dots, with: .color(second))
        }
    }

    // MARK: Marbling

    @ViewBuilder func marbled(w: CGFloat, h: CGFloat) -> some View {
        let palette = [colour, stock, second, shade(house.colour, .white, 0.55), Color(hex: "3B2A20")]
        let marble = Marbling(seed: book.designKey + edition.id, colours: palette, bands: [26, 34, 20][v])
        switch edition.composition {
        case 0:
            // Marbled boards, a leather spine and corners, a label.
            let leather = Color(hex: "5A3A28")
            ZStack(alignment: .topLeading) {
                marble
                HStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        leather
                        foil.frame(width: max(0.6, w * 0.006))
                    }
                    .frame(width: w * 0.17)
                    Spacer()
                }
                Canvas { ctx, size in
                    let c = w * 0.17
                    for y in [0, size.height] {
                        var corner = Path()
                        corner.move(to: CGPoint(x: size.width, y: y))
                        corner.addLine(to: CGPoint(x: size.width - c, y: y))
                        corner.addLine(to: CGPoint(x: size.width, y: y == 0 ? c : size.height - c))
                        corner.closeSubpath()
                        ctx.fill(corner, with: .color(leather))
                    }
                }
                label(w: w, h: h).padding(.top, h * 0.14).frame(maxWidth: .infinity).padding(.leading, w * 0.17)
            }
        case 1:
            VStack(spacing: 0) {
                marble.frame(height: h * [0.45, 0.38, 0.52][v]).clipped()
                Rectangle().fill(colour).frame(height: max(1, w * 0.01))
                ZStack {
                    stock
                    VStack(spacing: h * 0.02) {
                        title(dark, size: w * 0.095, width: w * 0.78, height: h * 0.22)
                        byline(colour, size: w * 0.046, italic: true)
                        Spacer(minLength: 0)
                        foot(colour, w: w)
                    }
                    .padding(.vertical, h * 0.04)
                }
            }
        default:
            ZStack {
                marble
                ZStack {
                    stock
                    VStack(spacing: h * 0.025) {
                        Spacer()
                        title(dark, size: w * 0.095, width: w * 0.62, height: h * 0.32)
                        rule(colour, w: w, width: w * 0.3)
                        byline(colour, size: w * 0.044, italic: true)
                        Spacer()
                        foot(colour, w: w)
                    }
                    .padding(.vertical, h * 0.04)
                }
                .overlay(Rectangle().stroke(Color(hex: "3B2A20").opacity(0.6), lineWidth: max(0.5, w * 0.004)))
                .padding(w * [0.1, 0.13, 0.08][v])
            }
        }
    }

    // MARK: Letterpress

    @ViewBuilder func letterpress(w: CGFloat, h: CGFloat) -> some View {
        switch edition.composition {
        case 0:
            // A title page, the type bitten into the stock.
            let titleInk = v == 2 ? colour : dark
            ZStack {
                stock
                VStack(spacing: h * 0.022) {
                    Text(edition.name.uppercased()).font(face.font(size: w * 0.036)).tracking(w * 0.02).foregroundStyle(dark)
                    rule(colour, w: w, width: w * 0.78)
                    Spacer()
                    ZStack {
                        title(.white.opacity(0.8), size: w * (v == 1 ? 0.12 : 0.1), width: w * 0.76, height: h * 0.32).offset(y: max(0.5, w * 0.003))
                        title(titleInk, size: w * (v == 1 ? 0.12 : 0.1), width: w * 0.76, height: h * 0.32)
                    }
                    Text(Array(repeating: ornament(edition.ornament), count: 3).joined(separator: "  "))
                        .font(.system(size: w * 0.04)).foregroundStyle(colour)
                    byline(dark, size: w * 0.048, caps: true, tracking: w * 0.01)
                    Spacer()
                    rule(colour, w: w, width: w * 0.78)
                    foot(colour, w: w, number: false)
                }
                .padding(.vertical, h * 0.07)
            }
        case 1:
            // Wood type: the title in its biggest letters, line by line, the grain in the ink.
            let words = book.title.uppercased().split(separator: " ").map(String.init)
            ZStack {
                stock
                VStack(spacing: h * 0.008) {
                    Rectangle().fill(dark).frame(height: max(1, w * 0.016))
                    ForEach(Array(words.prefix(6).enumerated()), id: \.offset) { i, word in
                        Text(word)
                            .font(face.font(size: w * 0.3, bold: true))
                            .foregroundStyle((i + v).isMultiple(of: 2) ? dark : colour)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .frame(maxWidth: .infinity)
                    }
                    Spacer(minLength: 0)
                    byline(dark, size: w * 0.05, caps: true, tracking: w * 0.01)
                    Rectangle().fill(dark).frame(height: max(1, w * 0.016))
                    HStack {
                        Text(edition.name.uppercased()).font(face.font(size: w * 0.032))
                        Spacer()
                        Text(house.catalogue).font(face.font(size: w * 0.032))
                    }
                    .foregroundStyle(dark)
                }
                .padding(w * 0.07)
                // The grain of the wood in the letters.
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image),
                                                                                      scale: Print.tileScale(coverWidth: size.width) * 1.4))
                }
                .blendMode(.screen)
                .opacity(0.35)
            }
        default:
            // A border of printers' flowers.
            let glyph = ornament(edition.ornament)
            ZStack {
                stock
                Canvas { ctx, size in
                    let step = w * [0.07, 0.055, 0.09][v]
                    var flower = ctx.resolve(Text(glyph).font(.system(size: step * 0.75)))
                    flower.shading = .color(colour)
                    let inset = w * 0.06
                    var x = inset
                    while x <= size.width - inset + 0.1 {
                        ctx.draw(flower, at: CGPoint(x: x, y: inset)); ctx.draw(flower, at: CGPoint(x: x, y: size.height - inset))
                        x += step
                    }
                    var y = inset + step
                    while y < size.height - inset {
                        ctx.draw(flower, at: CGPoint(x: inset, y: y)); ctx.draw(flower, at: CGPoint(x: size.width - inset, y: y))
                        y += step
                    }
                }
                VStack(spacing: h * 0.025) {
                    Spacer()
                    title(dark, size: w * 0.1, width: w * 0.66, height: h * 0.34)
                    Text(glyph).font(.system(size: w * 0.05)).foregroundStyle(colour)
                    byline(dark, size: w * 0.046, italic: true)
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(.vertical, h * 0.1)
            }
        }
    }

    // MARK: Linocut

    func carvedBlock(w: CGFloat, h: CGFloat, height: CGFloat, @ViewBuilder cuts: () -> some View) -> some View {
        ZStack { colour; cuts() }
            .frame(height: height)
            .clipShape(RoughRect(seed: book.id + edition.id))
            .padding(.horizontal, w * 0.07)
    }

    @ViewBuilder func linocut(w: CGFloat, h: CGFloat) -> some View {
        let blockHeight = h * [0.56, 0.5, 0.62][v]
        ZStack(alignment: .top) {
            stock
            VStack(spacing: h * 0.025) {
                Group {
                    switch edition.composition {
                    case 0: carvedBlock(w: w, h: h, height: blockHeight) { LinoLandscape(paper: stock, seed: book.id) }
                    case 1: carvedBlock(w: w, h: h, height: blockHeight) { LinoMoon(paper: stock, ink: colour) }
                    default:
                        carvedBlock(w: w, h: h, height: blockHeight) {
                            ZStack {
                                LinoWaves(paper: stock, seed: book.id)
                                title(colour, size: w * 0.1, width: w * 0.56, height: blockHeight * 0.36)
                                    .padding(w * 0.03)
                                    .background(stock)
                            }
                        }
                    }
                }
                .padding(.top, h * 0.06)
                if edition.composition != 2 { title(colour, size: w * 0.1, width: w * 0.8, height: h * 0.16) }
                byline(dark, size: w * 0.048)
                Spacer(minLength: 0)
                foot(colour, w: w)
            }
            .padding(.bottom, h * 0.04)
        }
    }

    // MARK: Engraving

    @ViewBuilder func engraving(w: CGFloat, h: CGFloat) -> some View {
        switch edition.composition {
        case 0:
            ZStack(alignment: .top) {
                stock
                VStack(spacing: h * 0.025) {
                    EngravedVignette(ink: colour, moonAt: [0.32, 0.68, 0.5][v])
                        .frame(width: w * 0.66, height: h * 0.42)
                        .clipShape(Ellipse())
                        .overlay(Ellipse().stroke(colour, lineWidth: max(0.6, w * 0.006)))
                        .overlay(Ellipse().stroke(colour, lineWidth: max(0.5, w * 0.003)).padding(-w * 0.018))
                        .padding(.top, h * 0.07)
                    title(dark, size: w * 0.075, width: w * 0.8, height: h * 0.16, caps: true, tracking: w * 0.006)
                    byline(colour, size: w * 0.042, caps: true, tracking: w * 0.008)
                    Spacer(minLength: 0)
                    foot(colour, w: w)
                }
                .padding(.bottom, h * 0.04)
            }
        case 1:
            ZStack {
                stock
                EngravedBorder(ink: colour, inset: w * [0.06, 0.08, 0.05][v])
                VStack(spacing: h * 0.025) {
                    Spacer()
                    VStack(spacing: h * 0.02) {
                        title(dark, size: w * 0.095, width: w * 0.56, height: h * 0.28)
                        Text(ornament(edition.ornament)).font(.system(size: w * 0.05)).foregroundStyle(colour)
                        byline(dark, size: w * 0.046, italic: true).frame(width: w * 0.56).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(w * 0.05)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.05).stroke(colour, lineWidth: max(0.5, w * 0.004)))
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(.vertical, h * 0.08)
            }
        default:
            ZStack(alignment: .top) {
                stock
                VStack(spacing: h * 0.025) {
                    Guilloche(ink: colour, accent: second, loops: [7, 9, 11][v])
                        .frame(width: w * 0.7, height: w * 0.7)
                        .padding(.top, h * 0.07)
                    title(dark, size: w * 0.095, width: w * 0.8, height: h * 0.2)
                    byline(colour, size: w * 0.044, caps: true, tracking: w * 0.008)
                    Spacer(minLength: 0)
                    foot(colour, w: w)
                }
                .padding(.bottom, h * 0.04)
            }
        }
    }

    // MARK: Overprint

    @ViewBuilder func overprint(w: CGFloat, h: CGFloat) -> some View {
        let slip = CGSize(width: max(0.8, w * 0.005), height: max(0.6, w * 0.004))
        ZStack(alignment: .top) {
            stock
            ZStack {
                switch edition.composition {
                case 0:
                    Circle().fill(colour).frame(width: w * 0.6, height: w * 0.6).offset(x: w * [-0.12, 0.12, 0][v], y: -h * 0.06)
                    Rectangle().fill(second).frame(width: w * 1.2, height: h * 0.1)
                        .rotationEffect(.degrees([-18, 14, -8][v])).offset(x: slip.width, y: h * 0.08 + slip.height)
                        .blendMode(.multiply)
                case 1:
                    Arcs(count: 7).stroke(colour, lineWidth: w * 0.035).frame(width: w * 0.9, height: w * 0.9).offset(x: -w * 0.18, y: -h * 0.02)
                    Arcs(count: 7).stroke(second, lineWidth: w * 0.035).frame(width: w * 0.9, height: w * 0.9)
                        .rotationEffect(.degrees(180)).offset(x: w * 0.18 + slip.width, y: h * 0.04 + slip.height)
                        .blendMode(.multiply)
                default:
                    Rectangle().fill(colour).frame(width: w * 0.5, height: h * 0.32).offset(x: -w * 0.14, y: -h * 0.08)
                    Rectangle().fill(second).frame(width: w * 0.5, height: h * 0.32).offset(x: w * 0.1, y: h * 0.02).blendMode(.multiply)
                    Rectangle().fill(Color(hex: "E8B931")).frame(width: w * 0.36, height: h * 0.22)
                        .offset(x: w * [-0.02, 0.2, -0.22][v] + slip.width, y: h * 0.14 + slip.height).blendMode(.multiply)
                }
            }
            .frame(width: w, height: h * 0.55)
            .clipped()
            .compositingGroup()
            VStack(alignment: .leading, spacing: h * 0.015) {
                Spacer()
                title(dark, size: w * 0.1, width: w * 0.84, height: h * 0.2, align: .leading)
                byline(dark, size: w * 0.046)
                foot(dark, w: w, alignment: .leading).padding(.top, h * 0.02)
            }
            .padding(w * 0.08)
        }
    }

    // MARK: Halftone

    @ViewBuilder func halftone(w: CGFloat, h: CGFloat) -> some View {
        switch edition.composition {
        case 0:
            ZStack {
                stock
                Halftone(ink: colour, angle: 45, pitch: w * [0.022, 0.017, 0.028][v]) { p, size in max(0, 1 - p.y / (size.height * 0.48)) }
                Halftone(ink: second, angle: 15, pitch: w * [0.022, 0.017, 0.028][v]) { p, size in
                    // The sea: densest at the horizon, gone before the house's mark.
                    let t = (p.y - size.height * 0.58) / (size.height * 0.2)
                    return t < 0 || t > 1 ? 0 : 1 - t
                }
                    .blendMode(.multiply)
                VStack(spacing: h * 0.012) {
                    title(dark, size: w * 0.095, width: w * 0.78, height: h * 0.16)
                    byline(dark, size: w * 0.045)
                }
                .padding(.vertical, h * 0.03)
                .frame(maxWidth: .infinity)
                .background(stock)
                foot(dark, w: w).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, h * 0.04)
            }
        case 1:
            ZStack(alignment: .bottomLeading) {
                stock
                Halftone(ink: colour, angle: 30, pitch: w * [0.024, 0.019, 0.03][v]) { p, size in
                    let fall = 1 - p.y / (size.height * 0.6)
                    return max(0, min(1, fall * (0.55 + 0.45 * p.x / size.width) * 1.4))
                }
                VStack(alignment: .leading, spacing: h * 0.012) {
                    title(dark, size: w * 0.11, width: w * 0.8, height: h * 0.22, align: .leading)
                    byline(dark, size: w * 0.046)
                    foot(dark, w: w, alignment: .leading).padding(.top, h * 0.02)
                }
                .padding(w * 0.08)
            }
        default:
            // Ben-Day dots in a panel, a solid block across it.
            ZStack(alignment: .top) {
                stock
                ZStack {
                    Halftone(ink: second, angle: 0, pitch: w * [0.035, 0.028, 0.045][v]) { _, _ in 0.55 }
                    Rectangle().fill(colour).frame(width: w * 0.5, height: h * 0.2).offset(x: w * 0.14, y: h * 0.1).blendMode(.multiply)
                }
                .frame(height: h * 0.5)
                .clipped()
                .overlay(Rectangle().stroke(dark, lineWidth: max(1, w * 0.012)))
                .padding(w * 0.07)
                VStack(spacing: h * 0.012) {
                    Spacer()
                    title(dark, size: w * 0.13, width: w * 0.86, height: h * 0.2, caps: true)
                    byline(dark, size: w * 0.046, caps: true)
                    foot(dark, w: w).padding(.top, h * 0.01)
                }
                .padding(.bottom, h * 0.04)
            }
        }
    }

    // MARK: Screen print

    @ViewBuilder func screenprint(w: CGFloat, h: CGFloat) -> some View {
        let slip = CGSize(width: max(1, w * 0.008), height: max(0.8, w * 0.006))
        ZStack(alignment: .top) {
            stock
            switch edition.composition {
            case 0:
                ZStack(alignment: .top) {
                    colour.frame(height: h * 0.5)
                    Circle().fill(stock).frame(width: w * 0.3, height: w * 0.3)
                        .offset(x: w * [0.18, -0.2, 0][v] + slip.width, y: h * 0.14 + slip.height)
                    second.frame(height: h * 0.15).offset(x: -slip.width, y: h * 0.35).blendMode(.multiply)
                }
                .frame(height: h * 0.5)
            case 1:
                let initial = String(book.title.first ?? "A").uppercased()
                ZStack {
                    Text(initial).font(face.font(size: w * 0.9, bold: true)).foregroundStyle(second).offset(x: slip.width * 3, y: slip.height * 3)
                    Text(initial).font(face.font(size: w * 0.9, bold: true)).foregroundStyle(colour).blendMode(.multiply)
                }
                .frame(width: w, height: h * 0.52)
            default:
                Rays(count: [16, 12, 20][v]).fill(colour).frame(width: w, height: h * 0.5).clipped()
            }
            VStack(spacing: h * 0.012) {
                Spacer()
                title(dark, size: w * 0.12, width: w * 0.86, height: h * 0.2, caps: true)
                byline(colour, size: w * 0.048, caps: true, tracking: w * 0.008)
                foot(dark, w: w).padding(.top, h * 0.01)
            }
            .padding(.bottom, h * 0.04)
            Image(uiImage: Print.mottle).resizable(resizingMode: .tile).blendMode(.screen).opacity(0.5)
        }
    }

    // MARK: Pulp

    @ViewBuilder func pulp(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            stock
            switch edition.composition {
            case 0:
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        colour
                        Text(house.catalogue.uppercased()).font(face.font(size: w * 0.04, bold: true)).foregroundStyle(stock).padding(w * 0.07)
                        title(stock, size: w * 0.12, width: w * 1.1, height: h * 0.18)
                            .padding(.vertical, h * 0.015)
                            .background(Color(hex: "15130F"))
                            .rotationEffect(.degrees([-6, -9, 5][v]))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: h * 0.72)
                    .clipped()
                    VStack(spacing: h * 0.01) {
                        byline(dark, size: w * 0.05, caps: true)
                        Text(edition.name.uppercased()).font(face.font(size: w * 0.032, bold: true)).foregroundStyle(colour)
                    }
                    .padding(.top, h * 0.04)
                }
            case 1:
                ZStack {
                    SplitDiagonal(rising: v != 1).fill(colour)
                    SplitDiagonal(rising: v != 1).fill(second).rotationEffect(.degrees(180))
                    VStack(spacing: h * 0.01) {
                        Text(house.catalogue.uppercased()).font(face.font(size: w * 0.04, bold: true)).foregroundStyle(stock)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        title(stock, size: w * 0.16, width: w * 0.86, height: h * 0.36, caps: true)
                            .shadow(color: Color(hex: "15130F"), radius: 0, x: w * 0.008, y: w * 0.008)
                        Spacer()
                        byline(stock, size: w * 0.05, caps: true)
                        Text(edition.name.uppercased()).font(face.font(size: w * 0.032, bold: true)).foregroundStyle(stock)
                    }
                    .padding(w * 0.07)
                }
            default:
                ZStack {
                    Color(hex: "15130F")
                    // A spotlight in the dark: the book's colour, lit.
                    RadialGradient(colors: [shade(house.colour, .white, 0.35), shade(house.colour, .white, 0.1).opacity(0.6), .clear],
                                   center: UnitPoint(x: [0.5, 0.3, 0.7][v], y: 0.34), startRadius: 0, endRadius: w * 0.72)
                    VStack(spacing: h * 0.015) {
                        Spacer()
                        title(stock, size: w * 0.12, width: w * 0.84, height: h * 0.26)
                        byline(shade(house.colour, .white, 0.5), size: w * 0.05, caps: true)
                        Text(edition.name.uppercased()).font(face.font(size: w * 0.032, bold: true)).foregroundStyle(stock.opacity(0.8))
                            .padding(.top, h * 0.03)
                    }
                    .padding(.bottom, h * 0.06)
                }
            }
            // Cheap paper, browned at the edges.
            RadialGradient(colors: [.clear, Color(hex: "6B4E22").opacity(0.35)], center: .center, startRadius: w * 0.4, endRadius: w * 1.1)
                .blendMode(.multiply)
        }
    }

    // MARK: Deckle

    @ViewBuilder func deckle(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            stock
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image),
                                                                                  scale: Print.tileScale(coverWidth: size.width) * 0.8))
            }
            .blendMode(.softLight)
            .opacity(0.8)
            switch edition.composition {
            case 0:
                VStack(spacing: h * 0.025) {
                    Spacer()
                    title(dark, size: w * 0.075, width: w * 0.7, height: h * 0.2, caps: true, bold: false, tracking: w * 0.012)
                    rule(colour, w: w, width: w * 0.24)
                    Text(ornament(edition.ornament)).font(.system(size: w * 0.04)).foregroundStyle(colour)
                    byline(dark, size: w * 0.046, italic: true)
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(.vertical, h * 0.08)
            case 1:
                VStack(spacing: h * 0.03) {
                    VStack(spacing: h * 0.01) {
                        title(dark, size: w * 0.12, width: w * 0.62, height: h * 0.2, bold: false)
                        rule(colour, w: w, width: w * 0.2)
                    }
                    .padding(w * 0.04)
                    .background(Color(hex: "F8F4EA"))
                    .overlay(Rectangle().stroke(colour.opacity(0.7), lineWidth: max(0.5, w * 0.003)).padding(w * 0.012))
                    .rotationEffect(.degrees([-1.6, 1.2, -0.6][v]))
                    .shadow(color: .black.opacity(0.22), radius: 1, x: 0.4, y: 0.9)
                    .padding(.top, h * 0.14)
                    byline(dark, size: w * 0.046, italic: true)
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(.bottom, h * 0.06)
            default:
                VStack(spacing: h * 0.025) {
                    ZStack {
                        // The plate pressed into the paper: shadow along two edges, light along two.
                        Rectangle().stroke(Color.black.opacity(0.18), lineWidth: 1.2).offset(x: -0.6, y: -0.6)
                        Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1.2).offset(x: 0.6, y: 0.6)
                        VStack(spacing: h * 0.02) {
                            title(dark, size: w * 0.09, width: w * 0.56, height: h * 0.26)
                            byline(colour, size: w * 0.042, italic: true)
                        }
                    }
                    .frame(width: w * 0.68, height: h * [0.5, 0.44, 0.56][v])
                    .padding(.top, h * 0.1)
                    Spacer()
                    foot(colour, w: w)
                }
                .padding(.bottom, h * 0.06)
            }
        }
        .clipShape(Deckle(seed: book.id, foreEdgeRight: !book.rightToLeft))
    }

    // MARK: Deco

    @ViewBuilder func deco(w: CGFloat, h: CGFloat) -> some View {
        let ground = Color(uiColor: UIColor(hex: edition.stock).mixed(with: UIColor(hex: house.colour), 0.22))
        ZStack {
            ground
            switch edition.composition {
            case 0:
                Sunburst(lines: [36, 28, 44][v]).stroke(foil, lineWidth: max(0.5, w * 0.004)).opacity(0.85)
                    .frame(width: w, height: h)
            case 1:
                Ziggurat(steps: [5, 4, 6][v]).fill(foil).frame(height: h * 0.34).frame(maxHeight: .infinity, alignment: .bottom)
            default:
                Fan(rings: [7, 5, 9][v]).stroke(foil, lineWidth: max(0.6, w * 0.006)).frame(width: w * 1.1, height: w * 0.55)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Chevrons().stroke(foil, lineWidth: max(0.6, w * 0.005)).frame(width: w * 0.5, height: h * 0.06)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, h * 0.06)
            }
            Rectangle().stroke(foil, lineWidth: max(0.6, w * 0.006)).padding(w * 0.045)
            if edition.rules == .double { Rectangle().stroke(foil, lineWidth: max(0.5, w * 0.003)).padding(w * 0.065) }
            VStack(spacing: h * 0.025) {
                foilText(book.title, font: face.font(size: w * 0.11, bold: true), width: w * 0.72, height: h * 0.26)
                    .padding(.vertical, h * 0.02)
                    .background(ground.opacity(edition.composition == 0 ? 0.92 : 0))
                foilText(bylineText.uppercased(), font: face.font(size: w * 0.04), width: w * 0.7, height: w * 0.06)
                    .padding(.horizontal, w * 0.03).background(ground)
                Spacer()
                VStack(spacing: h * 0.008) {
                    foilText(edition.colophon, font: face.font(size: w * 0.05, bold: true), width: w * 0.2, height: w * 0.08)
                    foilText(edition.name.uppercased(), font: face.font(size: w * 0.028), width: w * 0.6, height: w * 0.04)
                }
                .padding(.horizontal, w * 0.04).padding(.vertical, h * 0.01).background(ground)
            }
            .padding(.vertical, h * (edition.composition == 1 ? 0.08 : 0.16))
            .padding(.bottom, edition.composition == 1 ? h * 0.3 : 0)
        }
    }

    // MARK: Swiss

    @ViewBuilder func swiss(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            stock
            switch edition.composition {
            case 0:
                colour.frame(width: w * 0.64, height: h * 0.46)
                    .frame(maxWidth: .infinity, alignment: [.topLeading, .topTrailing, .topLeading][v])
                    .padding(.top, v == 2 ? h * 0.08 : 0)
            case 1:
                VStack(alignment: .leading, spacing: h * 0.025) {
                    colour.frame(width: w * [0.82, 0.7, 0.9][v], height: h * 0.07)
                    second.frame(width: w * [0.56, 0.8, 0.5][v], height: h * 0.07)
                    dark.frame(width: w * [0.3, 0.42, 0.66][v], height: h * 0.07)
                }
                .padding(.top, h * 0.08)
            default:
                Canvas { ctx, size in
                    var grid = Path()
                    for i in 1..<4 { let x = size.width * CGFloat(i) / 4; grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
                    for j in 1..<6 { let y = size.height * CGFloat(j) / 6; grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
                    ctx.stroke(grid, with: .color(dark.opacity(0.35)), lineWidth: 0.5)
                    let cell = CGSize(width: size.width / 4, height: size.height / 6)
                    let spot = [(1, 1), (2, 0), (0, 2)][v]
                    let d = min(cell.width, cell.height) * 1.9
                    ctx.fill(Path(ellipseIn: CGRect(x: cell.width * CGFloat(spot.0) + cell.width - d / 2,
                                                    y: cell.height * CGFloat(spot.1) + cell.height - d / 2, width: d, height: d)),
                             with: .color(colour))
                }
            }
            VStack(alignment: .leading, spacing: h * 0.012) {
                Spacer()
                title(dark, size: w * 0.12, width: w * 0.84, height: h * 0.28, align: .leading)
                byline(dark, size: w * 0.046)
                Rectangle().fill(dark).frame(height: max(0.5, w * 0.004)).padding(.vertical, h * 0.01)
                HStack(alignment: .bottom) {
                    Text(edition.name).font(face.font(size: w * 0.034, bold: true))
                    Spacer()
                    Text(house.catalogue).font(face.font(size: w * 0.034))
                }
                .foregroundStyle(dark)
            }
            .padding(w * 0.08)
        }
    }

    // MARK: Riso

    @ViewBuilder func riso(w: CGFloat, h: CGFloat) -> some View {
        let drum = Color(hex: ["F2709C", "FFC93C", "00A19A"][v])
        let slip = CGSize(width: max(1, w * 0.01), height: max(0.8, w * 0.007))
        ZStack(alignment: .top) {
            stock
            ZStack {
                switch edition.composition {
                case 0:
                    Circle().fill(drum).frame(width: w * 0.62, height: w * 0.62).offset(x: -w * 0.1, y: -h * 0.05)
                    RoundedRectangle(cornerRadius: w * 0.1).fill(colour).frame(width: w * 0.5, height: h * 0.34)
                        .offset(x: w * 0.16 + slip.width, y: h * 0.06 + slip.height).blendMode(.multiply)
                case 1:
                    Halftone(ink: colour, angle: 15, pitch: w * 0.024) { p, size in max(0, 1 - p.y / size.height * 1.2) }
                    Halftone(ink: drum, angle: 75, pitch: w * 0.024) { p, size in max(0, p.y / size.height * 1.2 - 0.15) }
                        .offset(x: slip.width, y: slip.height).blendMode(.multiply)
                default:
                    VStack(spacing: h * 0.03) {
                        ForEach(0..<4, id: \.self) { i in
                            (i.isMultiple(of: 2) ? drum : colour).frame(width: w * [0.86, 0.6, 0.74, 0.44][i], height: h * 0.05)
                                .frame(maxWidth: .infinity, alignment: i.isMultiple(of: 2) ? .leading : .trailing)
                        }
                    }
                    .padding(.horizontal, w * 0.07)
                }
            }
            .frame(width: w, height: h * 0.5)
            .clipped()
            .compositingGroup()
            VStack(spacing: h * 0.012) {
                Spacer()
                ZStack {
                    title(drum, size: w * 0.12, width: w * 0.84, height: h * 0.22, caps: edition.composition == 2)
                        .offset(x: slip.width, y: slip.height)
                    title(colour, size: w * 0.12, width: w * 0.84, height: h * 0.22, caps: edition.composition == 2).blendMode(.multiply)
                }
                byline(colour, size: w * 0.046)
                foot(colour, w: w).padding(.top, h * 0.01)
            }
            .padding(.bottom, h * 0.04)
            // Riso ink sits grainy on the paper.
            Image(uiImage: Print.mottle).resizable(resizingMode: .tile).blendMode(.screen).opacity(0.7)
        }
    }
}
