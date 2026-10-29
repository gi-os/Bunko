import CoreGraphics
import Foundation

/// Everything about how a book looks that nobody chose: the bookshop it came from and that
/// shop's paper and its shade, its publisher's house, colour and layout, and the small accidents
/// of a real copy (where the stamp landed, how the slip was pasted). A series shares one look.
///
/// Every book on the shelf gets a different one (`assign`): no two books (series aside) wear the
/// same paper cover from the same shop, or the same publisher's cover.
struct Look: Equatable {
    /// A bookshop, as its stamp names it.
    struct Shop: Equatable {
        var stamp: String
        var shape: CoverStyle.StampShape
    }

    static let japaneseShops: [Shop] = [
        Shop(stamp: "文庫堂", shape: .seal), Shop(stamp: "北斗書房", shape: .seal), Shop(stamp: "雨読書店", shape: .circle),
        Shop(stamp: "かもめ書店", shape: .circle), Shop(stamp: "三日月堂", shape: .seal), Shop(stamp: "猫町書房", shape: .square),
        Shop(stamp: "灯り書店", shape: .seal), Shop(stamp: "坂の上書房", shape: .circle), Shop(stamp: "白樺書店", shape: .square),
        Shop(stamp: "港の本屋", shape: .circle), Shop(stamp: "栞書房", shape: .seal), Shop(stamp: "BUNKO", shape: .circle),
    ]

    static let englishShops: [Shop] = [
        Shop(stamp: "BUNKO", shape: .circle), Shop(stamp: "HARBOUR BOOKS", shape: .circle),
        Shop(stamp: "LANTERN BOOKSHOP", shape: .square), Shop(stamp: "THE READING ROOM", shape: .circle),
        Shop(stamp: "MOTH & CANDLE", shape: .square), Shop(stamp: "NORTH STAR BOOKS", shape: .circle),
        Shop(stamp: "OLD MILL BOOKS", shape: .square), Shop(stamp: "PAPER LANTERN", shape: .circle),
        Shop(stamp: "GULL BOOKS", shape: .circle), Shop(stamp: "RAINY DAY BOOKS", shape: .square),
        Shop(stamp: "HALF MOON BOOKS", shape: .circle), Shop(stamp: "QUIET HOURS", shape: .seal),
    ]

    /// Papers a Japanese shop might wrap a book in (Basil's is Basil Books' own).
    static let papers: [CoverStyle.Paper] = [.kraft, .washi, .linen, .newsprint, .indigo, .sakura, .matcha, .seigaiha, .asanoha]
    /// An English shop has those and thirty of its own.
    static let englishPapers: [CoverStyle.Paper] = papers + CoverStyle.Paper.english

    /// A publisher's colours, from the traditional ones: brick, indigo, evergreen, ochre,
    /// purple, sumi, peony, celadon, persimmon, olive, 納戸, umber, yamabuki, slate, grape, bamboo.
    static let colours = ["8E2F2A", "2F4F7F", "3F6B4A", "9A6A22", "5B3F73", "2E2B28", "A84E64", "3E6F78",
                          "B5552E", "6B7B3A", "1F4E5F", "7A4A2A", "B8862A", "4A5A7A", "8A3C5A", "2F6B5E"]

    var shop: Int
    var paper: CoverStyle.Paper
    /// Which batch of paper: a shade lighter (-1), as made (0), a shade darker (1).
    var shade: Int
    var imprint: House.Imprint
    /// An English book's English house, when it drew one of the forty-five rather than one of the
    /// fifteen Japanese houses in its English edition.
    var edition: EnglishHouse?
    var colour: String
    /// Which of its house's three layouts.
    var variant: Int
    /// Where the stamp was pressed: its turn in degrees and its shift, as shares of the cover.
    var stampTurn: Double
    var stampShift: CGSize
    /// How the title slip was pasted: its shift, as shares of the cover.
    var slipShift: CGSize
    /// Where the printed pattern starts, 0..<1.
    var phase: CGFloat

    static func of(_ book: Book) -> Look {
        var rng = SeededRandom(string: book.designKey + "look")
        func pick<T>(_ options: [T]) -> T { options[Int.random(in: 0..<options.count, using: &rng)] }
        let shops = book.printsJapanese ? japaneseShops : englishShops
        var look = Look(shop: Int.random(in: 0..<shops.count, using: &rng),
                        paper: pick(papers),
                        shade: Int.random(in: -1...1, using: &rng),
                        imprint: pick(House.Imprint.allCases),
                        edition: nil,
                        colour: pick(colours),
                        variant: Int.random(in: 0...2, using: &rng),
                        stampTurn: .random(in: -14...5, using: &rng),
                        stampShift: CGSize(width: .random(in: -0.05...0.05, using: &rng), height: .random(in: -0.04...0.03, using: &rng)),
                        slipShift: CGSize(width: .random(in: -0.02...0.02, using: &rng), height: .random(in: -0.015...0.02, using: &rng)),
                        phase: .random(in: 0..<1, using: &rng))
        // An English book draws from sixty houses: the fifteen above in English, and forty-five of its own.
        if !book.printsJapanese {
            let draw = Int.random(in: 0..<(House.Imprint.allCases.count + EnglishHouse.all.count), using: &rng)
            if draw >= House.Imprint.allCases.count { look.edition = EnglishHouse.all[draw - House.Imprint.allCases.count] }
            // And from thirty-nine papers: the nine above and thirty English ones.
            look.paper = englishPapers[Int.random(in: 0..<englishPapers.count, using: &rng)]
        }
        return look
    }

    /// The house, whichever kind: an English house's id, or the Japanese house's name.
    var houseKey: String { edition.map { "en:" + $0.id } ?? imprint.rawValue }

    func shop(japanese: Bool) -> Shop {
        let shops = japanese ? Self.japaneseShops : Self.englishShops
        return shops[shop % shops.count]
    }

    /// What two paper covers must not share: the same shop's stamp on the same paper in the same shade.
    var paperSignature: String { "\(shop)|\(paper.rawValue)|\(shade)" }
    /// What two publisher's covers must not share: house, colour and layout.
    var houseSignature: String { "\(houseKey)|\(colour)|\(variant)" }
    /// A house's layout, whatever its colour: kept apart while there are layouts left.
    var layoutSignature: String { "\(houseKey)|\(variant)" }
    /// A shop's paper, whatever its shade: kept apart while there are papers left.
    var shopPaperSignature: String { "\(shop)|\(paper.rawValue)" }

    /// Gives every book without a look the first one, in the order they were added, that sets it
    /// apart: a house layout nobody has and a shop's paper nobody has, from a shop none of the last
    /// few books came from; once those run out (a big shelf), at least a paper cover and a
    /// publisher's cover nobody has. A series takes one look for all its volumes. Books keep looks
    /// they already have, so nothing changes under you.
    static func assign(_ books: [Book]) -> [Book] {
        var papers = Set<String>(), houses = Set<String>(), layouts = Set<String>(), shopPapers = Set<String>()
        // A Japanese house and its English edition are one design, so they share a key.
        var housesUsed = Set<String>(), paperKinds = Set<CoverStyle.Paper>()
        var recentShops: [Int] = []
        var seriesLooks: [String: Int] = [:]
        var result = books
        for i in books.indices.sorted(by: { (books[$0].addedAt, books[$0].id) < (books[$1].addedAt, books[$1].id) }) {
            var book = books[i]
            let series = book.volume.map { "series:" + $0.series.lowercased() }
            if book.look == nil {
                if let series, let shared = seriesLooks[series] {
                    book.look = shared
                } else {
                    func look(_ k: Int) -> Look { var candidate = book; candidate.look = k; return Look.of(candidate) }
                    func distinct(_ l: Look) -> Bool { !papers.contains(l.paperSignature) && !houses.contains(l.houseSignature) }
                    func fresh(_ l: Look) -> Bool {
                        distinct(l) && !layouts.contains(l.layoutSignature) && !shopPapers.contains(l.shopPaperSignature)
                            && !recentShops.contains(l.shop)
                    }
                    // A new house and a new paper while there are any; then a new layout and shop paper;
                    // past those (45 layouts), anything nobody has. Don't search tiers already spent.
                    let japanese = book.printsJapanese
                    let used = housesUsed
                    let newHouses = japanese
                        ? used.filter { !$0.hasPrefix("en:") }.count < House.Imprint.allCases.count
                        : used.count < House.Imprint.allCases.count + EnglishHouse.all.count
                    let freshLeft = layouts.count < (House.Imprint.allCases.count * 2 + EnglishHouse.all.count) * 3
                    func newest(_ l: Look) -> Bool {
                        let paperCount = japanese ? Self.papers.count : Self.englishPapers.count
                        return fresh(l) && !used.contains(l.houseKey) && (paperKinds.count >= paperCount || !paperKinds.contains(l.paper))
                    }
                    book.look = (newHouses ? (0..<800).first { newest(look($0)) } : nil)
                        ?? (freshLeft ? (0..<300).first { fresh(look($0)) } : nil)
                        ?? (0..<2000).first { distinct(look($0)) } ?? 0
                }
            }
            if let series, seriesLooks[series] == nil { seriesLooks[series] = book.look }
            let look = Look.of(book)
            papers.insert(look.paperSignature)
            houses.insert(look.houseSignature)
            layouts.insert(look.layoutSignature)
            housesUsed.insert(look.houseKey)
            paperKinds.insert(look.paper)
            shopPapers.insert(look.shopPaperSignature)
            recentShops = Array((recentShops + [look.shop]).suffix(4))
            result[i] = book
        }
        return result
    }
}
