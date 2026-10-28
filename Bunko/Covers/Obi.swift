import SwiftUI

/// The paper band (帯) round the foot of a cover. On a finished book it carries the day you
/// finished it; on the closed book you're reading, how much you read today. Never a goal or a
/// streak: just what happened.
struct Obi: Equatable {
    var headline: String
    var detail: String

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
        if japanese { return Obi(headline: "読了", detail: "\(date)・\(days)日間") }
        return Obi(headline: "Finished", detail: "\(date) · \(days == 1 ? "in a day" : "in \(days) days")")
    }

    /// The closed book in your hands: finished, or today's reading, or nothing for a book not yet begun.
    static func closed(_ progress: ReadingProgress?, japanese: Bool, now: Date = .now, calendar: Calendar = .current) -> Obi? {
        if let done = finished(progress, japanese: japanese, calendar: calendar) { return done }
        guard let progress else { return nil }
        let today = progress.pagesToday(now: now, calendar: calendar)
        guard today > 0 || progress.fraction > 0 else { return nil }
        let percent = Int((progress.fraction * 100).rounded())
        if japanese {
            return Obi(headline: today > 0 ? "今日 \(today)ページ" : "続きから", detail: "全体の\(percent)%")
        }
        return Obi(headline: today > 0 ? "\(today) \(today == 1 ? "page" : "pages") today" : "Pick up where you left off",
                   detail: "\(percent)% through")
    }
}

struct ObiView: View {
    let obi: Obi
    let japanese: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                Color(hex: "F4EEDF")
                Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile)
                VStack(spacing: h * 0.06) {
                    Text(obi.headline)
                        .font(Typesetter.swiftUIFont(japanese ? .mincho : .serif, size: h * 0.30, bold: true))
                    Text(obi.detail)
                        .font(Typesetter.swiftUIFont(japanese ? .mincho : .serif, size: h * 0.13))
                        .tracking(h * 0.01)
                }
                .foregroundStyle(Color(hex: "7A2E26"))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, geo.size.width * 0.08)
            }
            // The band sits on the cover: a shadow above, its own fold line below the top edge.
            .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.08)).frame(height: max(0.5, h * 0.012)) }
            .shadow(color: .black.opacity(0.25), radius: h * 0.03, y: -h * 0.01)
        }
        .accessibilityElement()
        .accessibilityLabel("\(obi.headline), \(obi.detail)")
    }
}

/// A cover that has been read: rubbed corners, a thumb-soft outer edge, a few creases. It grows
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
        }
        .allowsHitTesting(false)
    }
}
