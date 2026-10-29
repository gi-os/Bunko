import SwiftUI

/// The houses made by a way of printing or binding rather than a layout: a frame from a
/// typefounder's ornaments, thread, glassine, foil, an emboss, halftone dots, overprinted inks, a
/// woodblock, letterpress, and shibori. Each is what that process looks like in the hand.
extension HouseCover {
    @ViewBuilder func craftFace(w: CGFloat, h: CGFloat) -> some View {
        switch house.imprint {
        case .shimi: shimi(w: w, h: h)
        case .watoji: watoji(w: w, h: h)
        case .kirara: kirara(w: w, h: h)
        case .kinu: kinu(w: w, h: h)
        case .shimo: shimo(w: w, h: h)
        case .nichirin: nichirin(w: w, h: h)
        case .choyo: choyo(w: w, h: h)
        case .kodama: kodama(w: w, h: h)
        case .namari: namari(w: w, h: h)
        case .aizome: aizome(w: w, h: h)
        case .shirasagi, .tsukikage, .seirin, .chidori, .todai: EmptyView()
        }
    }

    /// 紙魚: parchment, a heavy rule and a hairline round it, a diamond at each corner, the title
    /// in a ruled box.
    private func shimi(w: CGFloat, h: CGFloat) -> some View {
        let brown = Color(hex: "4A3524")
        return ZStack {
            Color(hex: ["E9DDC2", "E3D3B1", "EFE6D2"][house.variant % 3])
            Rectangle().stroke(brown, lineWidth: max(1, w * 0.012)).padding(w * 0.06)
            Rectangle().stroke(brown.opacity(0.8), lineWidth: max(0.5, w * 0.004)).padding(w * 0.085)
            if house.variant == 2 { Rectangle().stroke(colour, lineWidth: max(0.5, w * 0.003)).padding(w * 0.1) }
            Canvas { ctx, size in
                // The corners: diamonds, rounds, or (with a third rule) nothing.
                guard house.variant != 2 else { return }
                let inset = w * 0.06, d = w * 0.028
                for p in [CGPoint(x: inset, y: inset), CGPoint(x: size.width - inset, y: inset),
                          CGPoint(x: inset, y: size.height - inset), CGPoint(x: size.width - inset, y: size.height - inset)] {
                    var corner = Path()
                    if house.variant == 1 {
                        corner.addEllipse(in: CGRect(x: p.x - d * 0.8, y: p.y - d * 0.8, width: d * 1.6, height: d * 1.6))
                    } else {
                        corner.addLines([CGPoint(x: p.x, y: p.y - d), CGPoint(x: p.x + d, y: p.y), CGPoint(x: p.x, y: p.y + d), CGPoint(x: p.x - d, y: p.y)])
                        corner.closeSubpath()
                    }
                    ctx.fill(corner, with: .color(brown))
                }
            }
            VStack(spacing: h * 0.03) {
                shelfCode(brown, w: w).frame(maxWidth: .infinity, alignment: vertical ? .leading : .trailing)
                title(brown, width: w * 0.56, height: h * 0.4, size: w * 0.095)
                    .padding(w * 0.035)
                    .overlay(Rectangle().stroke(colour, lineWidth: max(0.5, w * 0.006)))
                author(brown, w: w)
                Spacer()
                foot(brown, w: w)
            }
            .padding(w * 0.13)
        }
    }

    /// 和綴じ: dyed paper, four holes by the spine with thread round it, silk at the spine's
    /// corners, and the title slip at the outer head.
    private func watoji(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: vertical ? .topLeading : .topTrailing) {
            colour
            Color.black.opacity(0.12)
            Canvas { ctx, size in
                let spineX: CGFloat = vertical ? size.width : 0
                let inward: CGFloat = vertical ? -1 : 1
                let holeX = spineX + inward * w * 0.075
                let holes = [0.12, 0.37, 0.63, 0.88].map { size.height * $0 }
                var thread = Path()
                thread.move(to: CGPoint(x: holeX, y: 0))
                thread.addLine(to: CGPoint(x: holeX, y: size.height))
                for y in holes {
                    thread.move(to: CGPoint(x: holeX, y: y))
                    thread.addLine(to: CGPoint(x: spineX, y: y))
                }
                let width = max(1, w * 0.011)
                ctx.stroke(thread.offsetBy(dx: 0.5, dy: 0.8), with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: width, lineCap: .round))
                // Thread: undyed, vermilion, or gilt.
                ctx.stroke(thread, with: .color(Color(hex: ["EDE6D4", "B5362A", "D9B65A"][house.variant % 3])),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
                for y in holes {
                    let r = width * 0.9
                    ctx.fill(Path(ellipseIn: CGRect(x: holeX - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.black.opacity(0.45)))
                }
                // 角裂: silk over the spine's corners.
                let k = w * 0.075
                for y in [0, size.height - k] {
                    ctx.fill(Path(CGRect(x: vertical ? size.width - k : 0, y: y, width: k, height: k)), with: .color(Color(hex: "B89A55")))
                }
            }
            VStack(spacing: h * 0.012) {
                title(ink, width: vertical ? w * 0.2 : w * 0.56, height: vertical ? h * 0.5 : h * 0.16, size: w * 0.085)
                if !book.author.isEmpty {
                    Text(book.author).font(Typesetter.swiftUIFont(vertical ? .mincho : .serif, size: w * 0.04))
                        .foregroundStyle(ink.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.4)
                }
            }
            .padding(w * 0.03)
            .background(Color(hex: "F2ECDD"))
            .overlay(Rectangle().stroke(ink.opacity(0.35), lineWidth: max(0.5, w * 0.003)).padding(w * 0.012))
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0.4, y: 0.8)
            .padding(.top, h * 0.06)
            .padding(.horizontal, w * 0.08)
            foot(Color(hex: "EDE6D4"), w: w).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    /// パラフィン紙: a quiet printed cover under a glassine jacket, crinkled, catching the light,
    /// folded over the edges.
    private func kirara(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // The cover under the glassine: cream, a pale wash of its colour, or white.
            [cream, Color(uiColor: UIColor(hex: house.colour).mixed(with: .white, 0.8)), Color(hex: "FBFAF6")][house.variant % 3]
            VStack(spacing: h * 0.03) {
                title(ink, width: w * 0.6, height: h * 0.4, size: w * 0.09)
                author(colour, w: w)
                Spacer()
                foot(colour, w: w)
            }
            .padding(.top, h * 0.12)
            .padding(w * 0.1)
            Color.white.opacity(0.3)
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.crinkle.image),
                                                                                  scale: Print.tileScale(coverWidth: size.width) * 0.8))
            }
            .blendMode(.overlay)
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(stops: [.init(color: .white.opacity(0.28), location: 0), .init(color: .clear, location: 0.35),
                                     .init(color: .white.opacity(0.12), location: 0.6), .init(color: .clear, location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                // Folded over the head, the foot and the fore-edge.
                let fold = max(2, w * 0.025)
                for edge in [CGRect(x: 0, y: 0, width: size.width, height: fold), CGRect(x: 0, y: size.height - fold, width: size.width, height: fold),
                             CGRect(x: vertical ? 0 : size.width - fold, y: 0, width: fold, height: size.height)] {
                    ctx.fill(Path(edge), with: .color(.white.opacity(0.22)))
                }
            }
        }
    }

    /// Bookcloth, dark, its weave in it; the title and a frame stamped in gold foil.
    private func kinu(w: CGFloat, h: CGFloat) -> some View {
        // Gold, silver or copper foil.
        let foils = [["9C7A2E", "E9D58E", "B8933F", "F3E6B0", "8E6E28"], ["7D8086", "E6E8EB", "A5A9AF", "F5F6F7", "6E7177"],
                     ["8A4B2C", "E3A07A", "A8623E", "F0C3A4", "7A3F24"]]
        let gold = LinearGradient(colors: foils[house.variant % 3].map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        return ZStack {
            colour
            Color.black.opacity(0.58)
            // Bookcloth: the laid grain both ways, a weave.
            Canvas { ctx, size in
                let scale = Print.tileScale(coverWidth: size.width) * 0.5
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: scale))
                var across = ctx
                across.opacity = 0.5
                across.rotate(by: .degrees(90))
                across.fill(Path(CGRect(x: 0, y: -size.width, width: size.height, height: size.width)),
                            with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: scale))
            }
            .blendMode(.softLight)
            Rectangle().strokeBorder(gold, lineWidth: max(0.8, w * 0.006)).padding(w * 0.07)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0.4, y: 0.7)
            VStack(spacing: h * 0.04) {
                Spacer()
                gold.mask(title(.white, width: w * 0.66, height: h * 0.42, size: w * 0.1))
                    .frame(width: w * 0.66, height: h * 0.42)
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 0.5, y: 0.8)
                gold.mask(Text(book.author).font(Typesetter.swiftUIFont(vertical ? .mincho : .serif, size: w * 0.05))
                    .lineLimit(1).minimumScaleFactor(0.4))
                    .frame(height: w * 0.07)
                    .padding(.horizontal, w * 0.12)
                Spacer()
                gold.mask(colophonText(size: w * 0.06))
                    .frame(width: w * 0.1, height: w * 0.1)
                    .padding(.bottom, h * 0.08)
            }
        }
    }

    /// 空押し: pale paper and no ink on the title, only its relief catching the light.
    private func shimo(w: CGFloat, h: CGFloat) -> some View {
        let paper = Color(uiColor: UIColor(hex: house.colour).mixed(with: .white, [0.72, 0.6, 0.83][house.variant % 3]))
        return ZStack {
            paper
            VStack(spacing: h * 0.03) {
                Spacer()
                ZStack {
                    title(.white.opacity(0.55), width: w * 0.66, height: h * 0.46, size: w * 0.11).offset(x: -w * 0.003, y: -w * 0.003)
                    title(.black.opacity(0.24), width: w * 0.66, height: h * 0.46, size: w * 0.11).offset(x: w * 0.003, y: w * 0.004)
                        .blur(radius: w * 0.002)
                    title(paper, width: w * 0.66, height: h * 0.46, size: w * 0.11)
                }
                Spacer()
                author(colour.opacity(0.85), w: w)
                foot(colour.opacity(0.85), w: w)
            }
            .padding(w * 0.1)
        }
    }

    /// 網点: a sun in the author's colour, screened into dots that shrink towards its edge.
    private func nichirin(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            cream
            Canvas { ctx, size in
                // A vertical title runs down the fore-edge side, so the sun sits towards the spine.
                // The sun: centred, smaller and lower, or large and off to one side.
                let dx: CGFloat = [0, -0.06, 0.08][house.variant % 3], dy: CGFloat = [0, 0.04, -0.03][house.variant % 3]
                let centre = CGPoint(x: size.width * ((vertical ? 0.4 : 0.5) + dx), y: size.height * ((vertical ? 0.3 : 0.25) + dy))
                let radius = size.width * (vertical ? 0.33 : 0.34) * [1, 0.82, 1.15][house.variant % 3]
                let pitch = max(2.2, size.width * [0.02, 0.016, 0.026][house.variant % 3])
                let n = Int(radius * 1.5 / pitch)
                var dots = Path()
                for i in -n...n {
                    for j in -n...n {
                        // A 45° screen.
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
            if vertical {
                title(ink, width: w * 0.2, height: h * 0.58, size: w * 0.1)
                    .padding(.top, h * 0.06)
                    .padding(.trailing, w * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            VStack(spacing: h * 0.025) {
                Spacer()
                if !vertical { title(ink, width: w * 0.72, height: h * 0.26, size: w * 0.095) }
                author(colour, w: w)
                foot(ink, w: w)
            }
            .padding(w * 0.08)
        }
    }

    /// Two inks, overprinted where they cross, the second plate a hair out of register.
    private func choyo(w: CGFloat, h: CGFloat) -> some View {
        let second = Color(hex: house.colour == "9A6A22" ? "2F6F8F" : "D9A62E")
        return ZStack {
            cream
            ZStack {
                let slip = CGSize(width: max(0.8, w * 0.004), height: max(0.6, w * 0.003))
                switch house.variant % 3 {
                case 0:
                    Circle().fill(colour).frame(width: w * 0.56, height: w * 0.56).offset(x: -w * 0.1, y: -h * 0.27)
                    Rectangle().fill(second).frame(width: w * 0.44, height: h * 0.27)
                        .offset(x: w * 0.14 + slip.width, y: -h * 0.17 + slip.height)
                        .blendMode(.multiply)
                case 1:
                    Circle().fill(colour).frame(width: w * 0.5, height: w * 0.5).offset(x: -w * 0.12, y: -h * 0.25)
                    Circle().fill(second).frame(width: w * 0.5, height: w * 0.5)
                        .offset(x: w * 0.13 + slip.width, y: -h * 0.19 + slip.height)
                        .blendMode(.multiply)
                default:
                    Rectangle().fill(colour).frame(width: w * 0.62, height: h * 0.22).offset(x: -w * 0.06, y: -h * 0.27)
                    Triangle().fill(second).frame(width: w * 0.5, height: h * 0.32)
                        .offset(x: w * 0.1 + slip.width, y: -h * 0.2 + slip.height)
                        .blendMode(.multiply)
                }
            }
            .compositingGroup()
            VStack(spacing: h * 0.025) {
                Spacer()
                title(ink, width: w * 0.74, height: h * 0.22, size: w * 0.095)
                author(colour, w: w)
                foot(ink, w: w)
            }
            .padding(w * 0.08)
        }
    }

    /// 木版: a block cut from wood and pressed in the author's colour, the grain in the ink, the
    /// edges not quite straight, the title cut out of it so the paper shows.
    private func kodama(w: CGFloat, h: CGFloat) -> some View {
        // The third printing reverses it: a pale block pressed on the colour.
        let inverted = house.variant == 2
        return ZStack(alignment: .top) {
            inverted ? colour : cream
            ZStack {
                inverted ? cream : colour
                Canvas { ctx, size in
                    var grain = ctx
                    grain.rotate(by: .degrees(90))
                    grain.fill(Path(CGRect(x: 0, y: -size.width, width: size.height, height: size.width)),
                               with: .tiledImage(Image(uiImage: Print.Grain.laid.image), scale: Print.tileScale(coverWidth: size.width) * 1.6))
                }
                .blendMode(.overlay)
                title(inverted ? colour : cream, width: w * 0.66, height: h * 0.44, size: w * 0.12)
            }
            .frame(height: h * [0.6, 0.5, 0.56][house.variant % 3])
            .clipShape(RoughRect(seed: book.id))
            .padding(w * 0.07)
            VStack(spacing: h * 0.02) {
                Spacer()
                author(inverted ? cream : colour, w: w)
                foot(inverted ? cream : colour, w: w)
            }
        }
    }

    /// 活版: a typographic title page, the type bitten into the stock so light catches the
    /// impressions' lower edges.
    private func namari(w: CGFloat, h: CGFloat) -> some View {
        let rule = { (weight: CGFloat) in Rectangle().fill(colour).frame(height: max(0.6, w * weight)) }
        return ZStack {
            Color(hex: "F2EDE1")
            VStack(spacing: h * 0.022) {
                imprintLine(size: w * 0.042, w: w).foregroundStyle(ink)
                rule(0.008)
                rule(0.003)
                Spacer()
                ZStack {
                    title(.white.opacity(0.8), width: w * 0.72, height: h * 0.34, size: w * 0.1).offset(y: max(0.5, w * 0.003))
                    title(ink, width: w * 0.72, height: h * 0.34, size: w * 0.1)
                }
                HStack(spacing: w * 0.03) {
                    Rectangle().fill(colour).frame(width: w * 0.12, height: max(0.5, w * 0.003))
                    Text(["◇", "❖", "※"][house.variant % 3]).font(.system(size: w * 0.04)).foregroundStyle(colour)
                    Rectangle().fill(colour).frame(width: w * 0.12, height: max(0.5, w * 0.003))
                }
                author(ink, w: w)
                Spacer()
                shelfCode(ink, w: w)
                rule(0.003)
                rule(0.008)
                colophonText(size: w * 0.05).foregroundStyle(colour)
            }
            .padding(w * 0.1)
            // The head line clears the camera when the book fills the screen.
            .padding(.top, h * 0.04)
        }
    }

    /// 絞り: indigo cloth with little resist rings where it was bound before dyeing, soft at the
    /// edges; a slip pasted on for the title.
    private func aizome(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: vertical ? .topLeading : .top) {
            Color(hex: ["203556", "1A2A44", "2C4870"][house.variant % 3])
            Canvas { ctx, size in
                var rng = SeededRandom(string: book.id + "shibori")
                var resist = ctx
                resist.addFilter(.blur(radius: max(0.5, w * 0.005)))
                // Bound close and small, as made, or wide and large.
                let step = w * [0.11, 0.08, 0.15][house.variant % 3], r = w * [0.024, 0.017, 0.034][house.variant % 3]
                var row = 0
                var y = step * 0.5
                while y < size.height + step {
                    var x = (row.isMultiple(of: 2) ? 0 : step / 2) + step * 0.25
                    while x < size.width + step {
                        let p = CGPoint(x: x + .random(in: -1...1, using: &rng) * step * 0.08, y: y + .random(in: -1...1, using: &rng) * step * 0.08)
                        resist.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                      with: .color(Color(hex: "E3EAF2").opacity(.random(in: 0.45...0.75, using: &rng))), lineWidth: max(0.8, w * 0.011))
                        resist.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.3, y: p.y - r * 0.3, width: r * 0.6, height: r * 0.6)),
                                    with: .color(Color(hex: "E3EAF2").opacity(0.3)))
                        x += step
                    }
                    y += step * 0.86
                    row += 1
                }
            }
            VStack(spacing: h * 0.012) {
                title(ink, width: vertical ? w * 0.2 : w * 0.6, height: vertical ? h * 0.5 : h * 0.18, size: w * 0.085)
                if !book.author.isEmpty {
                    Text(book.author).font(Typesetter.swiftUIFont(vertical ? .mincho : .serif, size: w * 0.04))
                        .foregroundStyle(ink.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.4)
                }
            }
            .padding(w * 0.03)
            .background(Color(hex: "F3EEE2"))
            .overlay(Rectangle().stroke(ink.opacity(0.3), lineWidth: max(0.5, w * 0.003)).padding(w * 0.012))
            .shadow(color: .black.opacity(0.35), radius: 1.2, x: 0.4, y: 0.9)
            .padding(.top, h * 0.07)
            .padding(.horizontal, w * 0.1)
            foot(Color(hex: "E3EAF2"), w: w).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// A woodblock's edge: straight-ish, nicked here and there where the knife went.
struct RoughRect: Shape {
    var seed: String

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(string: seed + "block")
        let step: CGFloat = 5
        func wobble() -> CGFloat { .random(in: -1.1...1.1, using: &rng) }
        var path = Path()
        var x = rect.minX
        path.move(to: CGPoint(x: x, y: rect.minY + wobble()))
        while x < rect.maxX { x = min(x + step, rect.maxX); path.addLine(to: CGPoint(x: x, y: rect.minY + wobble())) }
        var y = rect.minY
        while y < rect.maxY { y = min(y + step, rect.maxY); path.addLine(to: CGPoint(x: rect.maxX + wobble(), y: y)) }
        while x > rect.minX { x = max(x - step, rect.minX); path.addLine(to: CGPoint(x: x, y: rect.maxY + wobble())) }
        while y > rect.minY { y = max(y - step, rect.minY); path.addLine(to: CGPoint(x: rect.minX + wobble(), y: y)) }
        path.closeSubpath()
        return path
    }
}

extension UIColor {
    /// This colour moved `amount` of the way to `other`.
    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount, blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount)
    }
}

/// A triangle standing on its base.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines([CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)])
        path.closeSubpath()
        return path
    }
}
