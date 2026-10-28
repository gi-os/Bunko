import SwiftUI

/// The obi as printed, in its style: its paper, rules and ornaments, the headline with any
/// number set big in the accent colour, the detail, and (where the style has one) a hairline
/// meter filling from the spine. Darker where it turns round the spine.
struct ObiView: View {
    let obi: Obi
    let japanese: Bool
    var spineOnRight = false
    var style: ObiStyle = .classic
    /// The wide obi repeats the title, the way a full-cover tie-in obi does.
    var title = ""
    var season = Season.of(.now)

    private struct Palette { var paper: Color; var ink: Color; var accent: Color }

    private var palette: Palette {
        switch style {
        case .classic:
            obi.finished ? Palette(paper: Color(hex: "B5362A"), ink: Color(hex: "F7EEDB"), accent: Color(hex: "F7EEDB"))
                         : Palette(paper: Color(hex: "F6F1E5"), ink: Color(hex: "2A241E"), accent: Color(hex: "B5362A"))
        case .milestone: Palette(paper: Color(hex: "F4D03F"), ink: Color(hex: "1A1714"), accent: Color(hex: "D0281C"))
        case .award: Palette(paper: Color(hex: "9E1F1A"), ink: Color(hex: "F6E9CC"), accent: Color(hex: "D8B45A"))
        case .quote: Palette(paper: Color(hex: "FBF8F1"), ink: Color(hex: "2A241E"), accent: Color(hex: "B5362A"))
        case .noir: Palette(paper: Color(hex: "171514"), ink: Color(hex: "EAE2D0"), accent: Color(hex: "C9A85C"))
        case .frost: Palette(paper: .white.opacity(0.35), ink: Color(hex: "2A241E"), accent: Color(hex: "B5362A"))
        case .wide: Palette(paper: Color(hex: "22304E"), ink: Color(hex: "F3EEE2"), accent: Color(hex: "E8B84A"))
        case .fair:
            switch season {
            case .spring: Palette(paper: Color(hex: "F2C4CE"), ink: Color(hex: "4E2230"), accent: Color(hex: "B5364A"))
            case .summer: Palette(paper: Color(hex: "2F8FB5"), ink: Color(hex: "F4FAFC"), accent: Color(hex: "F6D55C"))
            case .autumn: Palette(paper: Color(hex: "C8642B"), ink: Color(hex: "FFF4E0"), accent: Color(hex: "3A2414"))
            case .winter: Palette(paper: Color(hex: "2B3A5E"), ink: Color(hex: "EEF1F6"), accent: Color(hex: "E8C37A"))
            }
        }
    }

    private var face: ReaderSettings.Typeface { japanese ? .mincho : .serif }
    /// The outer edge, away from the spine: where badges and the coupon go.
    private var outer: Alignment { spineOnRight ? .leading : .trailing }

    var body: some View {
        GeometryReader { geo in
            // Type is sized to a normal band's height, so the wide obi gets room, not bigger type.
            let u = style == .wide ? geo.size.height * 0.52 : geo.size.height
            let w = geo.size.width
            // Badges and the coupon are sized to the band but never crowd a narrow one.
            let o = min(u, w * 0.32)
            let copy = obi.copy(style, japanese: japanese, season: season)
            let p = palette
            ZStack {
                paper(p)
                rules(p, u: u)
                ornaments(copy, p, o: o)
                text(copy, p, u: u, w: w)
                    // Clear of the badge on the outer edge; the fair's coupon both sides, to stay centred.
                    .padding(spineOnRight ? .leading : .trailing, copy.badge != nil ? o * 0.7 : 0)
                    .padding(.horizontal, style == .fair ? o * 0.4 : 0)
                // Where the band turns round the spine to the back.
                LinearGradient(colors: [.black.opacity(0.2), .clear],
                               startPoint: spineOnRight ? .trailing : .leading, endPoint: spineOnRight ? .leading : .trailing)
                    .frame(width: w * 0.07)
                    .frame(maxWidth: .infinity, alignment: spineOnRight ? .trailing : .leading)
            }
            // The band sits on the cover: a shadow above, its own fold line below the top edge.
            .overlay(alignment: .top) {
                Rectangle().fill(style == .frost ? .white.opacity(0.7) : .black.opacity(0.08)).frame(height: max(0.5, u * 0.012))
            }
            .shadow(color: .black.opacity(style == .frost ? 0.12 : 0.25), radius: u * 0.03, y: -u * 0.01)
        }
        .accessibilityElement()
        .accessibilityLabel("\(obi.headline), \(obi.detail)")
    }

    @ViewBuilder private func paper(_ p: Palette) -> some View {
        if style == .frost {
            // Tracing paper: the cover shows through, softened.
            Rectangle().fill(.ultraThinMaterial).overlay(p.paper)
        } else {
            p.paper
            Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(style == .noir || style == .wide ? 0.25 : 0.6)
        }
    }

    // MARK: Rules

    @ViewBuilder private func rules(_ p: Palette, u: CGFloat) -> some View {
        switch style {
        case .classic, .wide:
            VStack(spacing: 0) {
                doubleRule(p.accent, u: u, heavyFirst: true)
                Spacer()
                doubleRule(p.accent, u: u, heavyFirst: false)
            }
            .padding(.vertical, u * 0.08)
            .opacity(obi.finished && style == .classic ? 0.75 : 0.85)
        case .award, .noir:
            VStack(spacing: 0) {
                Rectangle().fill(p.accent).frame(height: max(0.5, u * 0.008))
                Spacer()
                Rectangle().fill(p.accent).frame(height: max(0.5, u * 0.008))
            }
            .padding(.vertical, u * 0.1)
            .padding(.horizontal, u * 0.12)
        case .milestone:
            // A heavy black bar along the foot, as the loud ones have.
            Rectangle().fill(p.ink).frame(height: u * 0.07).frame(maxHeight: .infinity, alignment: .bottom)
        case .quote, .fair, .frost:
            EmptyView()
        }
    }

    private func doubleRule(_ color: Color, u: CGFloat, heavyFirst: Bool) -> some View {
        VStack(spacing: u * 0.025) {
            Rectangle().fill(color).frame(height: max(1, u * (heavyFirst ? 0.022 : 0.008)))
            Rectangle().fill(color).frame(height: max(0.5, u * (heavyFirst ? 0.008 : 0.022)))
        }
    }

    // MARK: Ornaments

    @ViewBuilder private func ornaments(_ copy: ObiCopy, _ p: Palette, o: CGFloat) -> some View {
        switch style {
        case .milestone:
            if let badge = copy.badge {
                ZStack {
                    Starburst().fill(p.accent)
                    Text(badge)
                        .font(.system(size: o * 0.15, weight: .black))
                        .foregroundStyle(p.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(o * 0.1)
                }
                .frame(width: o * 0.62, height: o * 0.62)
                .rotationEffect(.degrees(-10))
                .padding(.horizontal, o * 0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: outer)
            }
        case .award:
            if let badge = copy.badge {
                ZStack {
                    // Gold printed flat, as obi ink is.
                    Circle().fill(p.accent)
                    Circle().stroke(Color(hex: "8C6A22"), lineWidth: max(0.5, o * 0.012)).padding(o * 0.04)
                    Circle().stroke(Color(hex: "8C6A22").opacity(0.6), style: StrokeStyle(lineWidth: max(0.5, o * 0.008), dash: [o * 0.015, o * 0.015]))
                        .padding(o * 0.07)
                    Text(badge)
                        .font(Typesetter.swiftUIFont(face, size: o * 0.15, bold: true))
                        .foregroundStyle(Color(hex: "6E1612"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(o * 0.1)
                }
                .frame(width: o * 0.6, height: o * 0.6)
                .padding(.horizontal, o * 0.12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: outer)
            }
        case .fair:
            // The 応募券 to cut out, at the outer foot.
            VStack(spacing: o * 0.008) {
                Text("応募券").font(.system(size: o * 0.07, weight: .bold))
                Text("\(season.label(japanese: true))").font(.system(size: o * 0.045, weight: .medium)).opacity(0.8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(p.ink)
            .frame(width: o * 0.38, height: o * 0.32)
            .overlay(Rectangle().stroke(p.ink, style: StrokeStyle(lineWidth: max(0.5, o * 0.008), dash: [o * 0.018, o * 0.012])))
            .padding(o * 0.05)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: spineOnRight ? .bottomLeading : .bottomTrailing)
        case .quote:
            // A big opening quote mark, printed pale behind the words.
            Text(japanese ? "「" : "“")
                .font(Typesetter.swiftUIFont(face, size: o * 0.9, bold: true))
                .foregroundStyle(p.accent.opacity(0.12))
                .offset(x: spineOnRight ? -o * 0.2 : o * 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: spineOnRight ? .topTrailing : .topLeading)
                .clipped()
        case .classic, .noir, .frost, .wide:
            EmptyView()
        }
    }

    // MARK: Words

    private func text(_ copy: ObiCopy, _ p: Palette, u: CGFloat, w: CGFloat) -> some View {
        VStack(spacing: u * 0.05) {
            if let label = copy.label {
                Text(label).font(.system(size: u * 0.085, weight: .heavy, design: .rounded)).tracking(u * 0.01)
                .foregroundStyle(p.paper)
                .padding(.horizontal, u * 0.08)
                .padding(.vertical, u * 0.015)
                .background(p.ink, in: Capsule())
            }
            if style == .wide, !title.isEmpty {
                Text(title)
                    .font(Typesetter.swiftUIFont(face, size: u * 0.13, bold: true))
                    .tracking(u * 0.02)
                    .foregroundStyle(p.ink.opacity(0.75))
                Rectangle().fill(p.accent).frame(width: u * 0.5, height: max(0.5, u * 0.008))
                    .padding(.bottom, u * 0.04)
            }
            headline(copy.headline, p, u: u)
            Text(copy.detail)
                .font(style == .quote ? Font.custom(japanese ? "ShipporiMincho-Regular" : "Literata-Italic", size: u * 0.11)
                                      : Typesetter.swiftUIFont(face, size: u * 0.115))
                .tracking(u * (style == .noir ? 0.03 : 0.012))
                .foregroundStyle(p.ink.opacity(0.75))
            if let fraction = obi.fraction, [ObiStyle.classic, .noir, .frost, .wide].contains(style) {
                meter(fraction, p, width: min(w * 0.34, u * 1.6), height: max(1, u * 0.022))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.horizontal, w * 0.08)
        .padding(.vertical, u * 0.14)
        // The big numerals carry their own headroom; lift the block to sit centred.
        .offset(y: copy.label == nil ? -u * 0.035 : 0)
    }

    /// The headline in the style's type, with any number in it bigger and in the accent colour.
    private func headline(_ headline: String, _ p: Palette, u: CGFloat) -> Text {
        let size = u * (style == .quote ? 0.2 : 0.27)
        let numbers = style != .quote
        return Obi.runs(headline).reduce(Text(verbatim: "")) { text, run in
            let big = numbers && run.number
            let part = Text(verbatim: run.text)
                .font(font(size: big ? size * (style == .milestone ? 1.5 : 1.4) : size))
                .foregroundColor(big ? p.accent : p.ink)
            return Text("\(text)\(part)")
        }
        .tracking(style == .noir ? u * 0.03 : 0)
    }

    private func font(size: CGFloat) -> Font {
        switch style {
        case .milestone: .system(size: size, weight: .black)
        case .fair: .system(size: size, weight: .heavy, design: .rounded)
        case .noir, .quote: Typesetter.swiftUIFont(face, size: size)
        case .classic, .award, .frost, .wide: Typesetter.swiftUIFont(face, size: size, bold: true)
        }
    }

    /// How far through, as a hairline filling from the spine.
    private func meter(_ fraction: Double, _ p: Palette, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: spineOnRight ? .trailing : .leading) {
            Capsule().fill(p.ink.opacity(0.15))
            Capsule().fill(p.accent).frame(width: width * min(max(fraction, 0), 1))
        }
        .frame(width: width, height: height)
    }
}

/// The loud obi's burst: a ring of points round a circle.
struct Starburst: Shape {
    var points = 14

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : r * 0.78
            let point = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
