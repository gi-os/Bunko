import SwiftUI

/// The paper band (帯) round the foot of a cover. On a finished book it carries the day you
/// finished it; on the closed book you're reading, how much you read today. Never a goal or a
/// streak: just what happened.
struct Obi: Equatable {
    var headline: String
    var detail: String
    /// A finished book's obi is printed in vermilion, so the shelf shows at a glance what's read.
    var finished = false
    /// How far through, for the hairline meter on the obi of a book being read.
    var fraction: Double?

    /// The headline cut into runs of digits and the rest: the numbers are set big and in red.
    static func runs(_ headline: String) -> [(text: String, number: Bool)] {
        var runs: [(text: String, number: Bool)] = []
        for ch in headline {
            // Digits only: 一 and 十 have numeric values too, but they're words here.
            let number = ch.unicodeScalars.allSatisfy { $0.properties.generalCategory == .decimalNumber }
            if let last = runs.last, last.number == number {
                runs[runs.count - 1].text.append(ch)
            } else {
                runs.append((String(ch), number))
            }
        }
        return runs
    }

    static func finished(_ progress: ReadingProgress?, japanese: Bool, calendar: Calendar = .current) -> Obi? {
        guard let progress, let finished = progress.finishedAt else { return nil }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        format.dateFormat = "yyyy.MM.dd"
        let date = format.string(from: finished)
        let start = calendar.startOfDay(for: progress.startedAt ?? finished)
        let days = max(1, (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: finished)).day ?? 0) + 1)
        if japanese { return Obi(headline: "読了", detail: "\(date)・\(days)日間", finished: true) }
        return Obi(headline: "Finished", detail: "\(date) · \(days == 1 ? "in a day" : "in \(days) days")", finished: true)
    }

    /// The closed book in your hands: finished, or today's reading, or nothing for a book not yet begun.
    static func closed(_ progress: ReadingProgress?, japanese: Bool, now: Date = .now, calendar: Calendar = .current) -> Obi? {
        if let done = finished(progress, japanese: japanese, calendar: calendar) { return done }
        guard let progress else { return nil }
        let today = progress.pagesToday(now: now, calendar: calendar)
        guard today > 0 || progress.fraction > 0 else { return nil }
        let percent = Int((progress.fraction * 100).rounded())
        if japanese {
            return Obi(headline: today > 0 ? "今日 \(today)ページ" : "続きから", detail: "全体の\(percent)%", fraction: progress.fraction)
        }
        return Obi(headline: today > 0 ? "\(today) \(today == 1 ? "page" : "pages") today" : "Pick up where you left off",
                   detail: "\(percent)% through", fraction: progress.fraction)
    }
}

/// The obi as printed: cream paper with a vermilion double rule, the headline in bold with its
/// number set big in red, and a hairline meter filling from the spine; a finished book's obi is
/// vermilion with cream type. Darker where it turns round the spine.
struct ObiView: View {
    let obi: Obi
    let japanese: Bool
    var spineOnRight = false

    private var paper: Color { Color(hex: obi.finished ? "B5362A" : "F6F1E5") }
    private var ink: Color { Color(hex: obi.finished ? "F7EEDB" : "2A241E") }
    private var accent: Color { Color(hex: obi.finished ? "F7EEDB" : "B5362A") }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let face: ReaderSettings.Typeface = japanese ? .mincho : .serif
            ZStack {
                paper
                Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile)
                    .blendMode(obi.finished ? .multiply : .normal)
                    .opacity(obi.finished ? 0.6 : 1)
                VStack(spacing: 0) {
                    rule(h: h, heavyFirst: true)
                    Spacer()
                    rule(h: h, heavyFirst: false)
                }
                .padding(.vertical, h * 0.08)
                VStack(spacing: h * 0.05) {
                    headline(size: h * 0.27, face: face)
                    Text(obi.detail)
                        .font(Typesetter.swiftUIFont(face, size: h * 0.115))
                        .tracking(h * 0.012)
                        .foregroundStyle(ink.opacity(obi.finished ? 0.9 : 0.7))
                    if let fraction = obi.fraction {
                        meter(fraction, width: w * 0.34, height: max(1, h * 0.022))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, w * 0.08)
                .padding(.vertical, h * 0.16)
                // The big numerals carry their own headroom; lift the block to sit centred.
                .offset(y: -h * 0.035)
                // Where the band turns round the spine to the back.
                LinearGradient(colors: [.black.opacity(0.2), .clear],
                               startPoint: spineOnRight ? .trailing : .leading, endPoint: spineOnRight ? .leading : .trailing)
                    .frame(width: w * 0.07)
                    .frame(maxWidth: .infinity, alignment: spineOnRight ? .trailing : .leading)
            }
            // The band sits on the cover: a shadow above, its own fold line below the top edge.
            .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.08)).frame(height: max(0.5, h * 0.012)) }
            .shadow(color: .black.opacity(0.25), radius: h * 0.03, y: -h * 0.01)
        }
        .accessibilityElement()
        .accessibilityLabel("\(obi.headline), \(obi.detail)")
    }

    /// Bold, with any number in it bigger and in the accent colour.
    private func headline(size: CGFloat, face: ReaderSettings.Typeface) -> Text {
        Obi.runs(obi.headline).reduce(Text(verbatim: "")) { text, run in
            let part = Text(verbatim: run.text)
                .font(Typesetter.swiftUIFont(face, size: run.number ? size * 1.4 : size, bold: true))
                .foregroundColor(run.number ? accent : ink)
            return Text("\(text)\(part)")
        }
    }

    /// A printed double rule: a heavy line and a hairline, the heavy one outermost.
    private func rule(h: CGFloat, heavyFirst: Bool) -> some View {
        VStack(spacing: h * 0.025) {
            Rectangle().fill(accent).frame(height: max(1, h * (heavyFirst ? 0.022 : 0.008)))
            Rectangle().fill(accent).frame(height: max(0.5, h * (heavyFirst ? 0.008 : 0.022)))
        }
        .opacity(obi.finished ? 0.75 : 0.85)
    }

    /// How far through, as a hairline filling from the spine.
    private func meter(_ fraction: Double, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: spineOnRight ? .trailing : .leading) {
            Capsule().fill(ink.opacity(0.15))
            Capsule().fill(accent).frame(width: width * min(max(fraction, 0), 1))
        }
        .frame(width: width, height: height)
    }
}

/// A cover that has been read: rubbed corners, a thumb-soft outer edge, a few creases, a spine
/// faded by the light and, once it's well read, the head corner turned down. It grows
/// with the pages read, so a loved book looks it.
struct WearOverlay: View {
    let wear: Double
    let seed: String
    let spineOnRight: Bool

    var body: some View {
        Canvas { ctx, size in
            guard wear > 0.02 else { return }
            let w = CGFloat(wear)
            var rng = SeededRandom(string: seed + "wear")
            // Rubbed corners and edges go pale.
            for corner in [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
                let r = size.width * (0.10 + 0.12 * w)
                ctx.fill(Path(ellipseIn: CGRect(x: corner.x - r, y: corner.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.35 * w), .clear]), center: corner, startRadius: 0, endRadius: r))
            }
            ctx.stroke(Path(CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)), with: .color(.white.opacity(0.25 * w)), lineWidth: 2)
            // Where the thumb holds it: the outer edge, a little below the middle.
            let thumb = CGPoint(x: spineOnRight ? 0 : size.width, y: size.height * 0.62)
            let tr = size.width * 0.45
            ctx.fill(Path(ellipseIn: CGRect(x: thumb.x - tr, y: thumb.y - tr, width: tr * 2, height: tr * 2)),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.10 * w), .clear]), center: thumb, startRadius: 0, endRadius: tr))
            // Creases from opening it wide, near the spine.
            for _ in 0..<Int(1 + w * 6) {
                let x = spineOnRight ? size.width * CGFloat.random(in: 0.72...0.9, using: &rng) : size.width * CGFloat.random(in: 0.1...0.28, using: &rng)
                let y = size.height * CGFloat.random(in: 0.05...0.95, using: &rng)
                let length = size.width * CGFloat.random(in: 0.06...0.2, using: &rng)
                let dx = spineOnRight ? -length : length
                let dy = CGFloat.random(in: -0.3...0.3, using: &rng) * length
                var crease = Path()
                crease.move(to: CGPoint(x: x, y: y))
                crease.addLine(to: CGPoint(x: x + dx, y: y + dy))
                ctx.stroke(crease, with: .color(.black.opacity(0.12 * w)), lineWidth: 0.8)
                ctx.stroke(crease.offsetBy(dx: 0, dy: 1), with: .color(.white.opacity(0.2 * w)), lineWidth: 0.8)
            }
            // The spine, faded by the light on the shelf.
            let spineX = spineOnRight ? size.width : 0
            let fade = size.width * 0.16
            ctx.fill(Path(CGRect(x: spineOnRight ? size.width - fade : 0, y: 0, width: fade, height: size.height)),
                     with: .linearGradient(Gradient(colors: [.white.opacity(0.24 * w), .white.opacity(0.08 * w), .clear]),
                                           startPoint: CGPoint(x: spineX, y: 0),
                                           endPoint: CGPoint(x: spineOnRight ? size.width - fade : fade, y: 0)))
            // A dog-ear: the head corner away from the spine folded over, the board showing beneath.
            let fold = size.width * Self.dogEar(wear)
            if fold > 0 {
                let edge: CGFloat = spineOnRight ? 0 : size.width
                let inward: CGFloat = spineOnRight ? 1 : -1
                let onHead = CGPoint(x: edge + inward * fold, y: 0)
                let onSide = CGPoint(x: edge, y: fold)
                let tip = CGPoint(x: edge + inward * fold, y: fold)
                var gone = Path()
                gone.addLines([onHead, CGPoint(x: edge, y: 0), onSide])
                ctx.fill(gone, with: .color(Color(hex: "E9E1CF")))
                var flap = Path()
                flap.addLines([onHead, onSide, tip])
                var lifted = ctx
                lifted.addFilter(.shadow(color: .black.opacity(0.3), radius: fold * 0.1, x: inward * fold * 0.04, y: fold * 0.05))
                lifted.fill(flap, with: .linearGradient(Gradient(colors: [Color(hex: "F4EFE4"), Color(hex: "D9D0BE")]),
                                                        startPoint: CGPoint(x: (onHead.x + onSide.x) / 2, y: fold / 2), endPoint: tip))
            }
        }
        .allowsHitTesting(false)
    }

    /// How far the dog-ear reaches along the head, as a share of the cover's width: none until a
    /// book is well read, then growing.
    static func dogEar(_ wear: Double) -> CGFloat {
        wear < 0.4 ? 0 : 0.05 + 0.07 * CGFloat((min(wear, 1) - 0.4) / 0.6)
    }
}
