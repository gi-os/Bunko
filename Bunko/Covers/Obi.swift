import SwiftUI

/// The paper band (帯) round the foot of a cover. On a finished book it carries the day you
/// finished it; on the closed book you're reading, how much you read today. Never a goal or a
/// streak: just what happened. How it's worded and printed depends on its `ObiStyle`.
struct Obi: Equatable {
    var headline: String
    var detail: String
    /// A finished book's obi is printed in vermilion, so the shelf shows at a glance what's read.
    var finished = false
    /// How far through, for the hairline meter on the obi of a book being read.
    var fraction: Double?
    /// The facts the styles word their own way: pages turned in all and today, and for a
    /// finished book the days it took and the day (yyyy.MM.dd).
    var pages = 0
    var today = 0
    var days = 0
    var date = ""

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
        var obi = japanese
            ? Obi(headline: "読了", detail: "\(date)・\(days)日間", finished: true)
            : Obi(headline: "Finished", detail: "\(date) · \(days == 1 ? "in a day" : "in \(days) days")", finished: true)
        obi.pages = progress.pagesRead
        obi.days = days
        obi.date = date
        return obi
    }

    /// The closed book in your hands: finished, or today's reading, or nothing for a book not yet begun.
    static func closed(_ progress: ReadingProgress?, japanese: Bool, now: Date = .now, calendar: Calendar = .current) -> Obi? {
        if let done = finished(progress, japanese: japanese, calendar: calendar) { return done }
        guard let progress else { return nil }
        let today = progress.pagesToday(now: now, calendar: calendar)
        guard today > 0 || progress.fraction > 0 else { return nil }
        let percent = Int((progress.fraction * 100).rounded())
        var obi = japanese
            ? Obi(headline: today > 0 ? "今日 \(today)ページ" : "続きから", detail: "全体の\(percent)%", fraction: progress.fraction)
            : Obi(headline: today > 0 ? "\(today) \(today == 1 ? "page" : "pages") today" : "Pick up where you left off",
                  detail: "\(percent)% through", fraction: progress.fraction)
        obi.pages = progress.pagesRead
        obi.today = today
        return obi
    }

    /// What the editor shows on a book with no reading yet.
    static func sample(japanese: Bool) -> Obi {
        var progress = ReadingProgress(offset: 0, ribbon: 0, fraction: 0.3)
        progress.recordTurn(pages: 12)
        progress.pagesRead = 120
        return closed(progress, japanese: japanese)!
    }

    /// The words a style prints. Most print the headline and detail as they are; the others
    /// say the same facts the way their kind of obi does.
    func copy(_ style: ObiStyle, japanese: Bool, season: Season) -> ObiCopy {
        let percent = fraction.map { "\(Int(($0 * 100).rounded()))%" }
        switch style {
        case .classic, .noir, .frost, .wide:
            return ObiCopy(headline: headline, detail: detail)
        case .milestone:
            // 「〇万部突破！」, counted in your own pages.
            guard pages > 0 else { return ObiCopy(headline: headline, detail: detail, badge: percent ?? (japanese ? "読了" : "Read")) }
            if finished {
                return ObiCopy(headline: japanese ? "全\(pages)ページ読破!" : "All \(pages) pages read!", detail: detail,
                               badge: japanese ? "読了" : "Read")
            }
            return ObiCopy(headline: japanese ? "累計\(pages)ページ突破!" : "\(pages) pages and counting!",
                           detail: japanese ? "\(headline)・\(detail)" : "\(headline) · \(detail)", badge: percent)
        case .award:
            if finished { return ObiCopy(headline: japanese ? "祝・読了" : "Read cover to cover", detail: detail, badge: japanese ? "読了" : "Read") }
            return ObiCopy(headline: headline, detail: detail, badge: percent)
        case .quote:
            // An endorsement, from you: what happened, in your words.
            if finished {
                return japanese
                    ? ObiCopy(headline: "「\(days)日間で読み終えた。」", detail: "—— \(date)のわたし")
                    : ObiCopy(headline: "“Read it in \(days == 1 ? "a day" : "\(days) days").”", detail: "— me, \(date)")
            }
            if today > 0 {
                return japanese
                    ? ObiCopy(headline: "「今日は\(today)ページ読んだ。」", detail: "—— 今日のわたし")
                    : ObiCopy(headline: "“\(today) \(today == 1 ? "page" : "pages") today.”", detail: "— me, today")
            }
            return japanese
                ? ObiCopy(headline: "「全体の\(percent ?? "")まで来た。」", detail: "—— わたし")
                : ObiCopy(headline: "“\(percent ?? "") of the way in.”", detail: "— me")
        case .fair:
            return ObiCopy(headline: headline, detail: detail, label: season.label(japanese: japanese))
        }
    }
}

/// What an obi prints: its headline and detail, a badge (starburst, medal) and a label above.
struct ObiCopy: Equatable {
    var headline: String
    var detail: String
    var badge: String?
    var label: String?
}

/// The kinds of obi a Japanese bookshop is full of, each carrying your reading in its own idiom.
enum ObiStyle: String, Codable, CaseIterable, Identifiable {
    /// 白帯: cream with a vermilion double rule.
    case classic
    /// 突破帯: loud yellow, 「累計〇ページ突破!」 and a starburst.
    case milestone
    /// 受賞帯: prize red with gold rules and a medal.
    case award
    /// 推薦帯: an endorsement in 「」, signed by you.
    case quote
    /// 黒帯: black and gold, the premium edition.
    case noir
    /// フェア帯: a publisher's seasonal fair, its cat and the 応募券 to cut out.
    case fair
    /// 半透明帯: translucent, the cover showing through.
    case frost
    /// 全面帯: half the cover, the title repeated, like a film tie-in.
    case wide

    var id: Self { self }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .milestone: "Milestone"
        case .award: "Award"
        case .quote: "Quote"
        case .noir: "Noir"
        case .fair: "Fair"
        case .frost: "Frosted"
        case .wide: "Wide"
        }
    }

    /// The band's height as a share of the cover's: the full-screen closed book, or a thumbnail.
    func height(large: Bool) -> CGFloat {
        self == .wide ? (large ? 0.42 : 0.5) : (large ? 0.22 : 0.27)
    }

    /// A book nobody has picked an obi for: one per book, by its ID, so the shelf is varied.
    static func automatic(for bookID: String) -> ObiStyle {
        let pick = bookID.unicodeScalars.reduce(7) { ($0 &* 33 &+ Int($1.value)) & 0xFFFF }
        return allCases[pick % allCases.count]
    }
}

/// The fair obi follows the season, the way the publishers' summer and autumn fairs do.
enum Season: CaseIterable {
    case spring, summer, autumn, winter

    static func of(_ date: Date, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }

    func label(japanese: Bool) -> String {
        switch self {
        case .spring: japanese ? "春の一冊" : "Spring Reads"
        case .summer: japanese ? "夏の一冊" : "Summer Reads"
        case .autumn: japanese ? "読書の秋" : "Autumn Reads"
        case .winter: japanese ? "冬の一冊" : "Winter Reads"
        }
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
