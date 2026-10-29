import Foundation

/// A bookshop paper cover (書店カバー) wrapped around a book. Synced through iCloud.
struct CoverStyle: Codable, Equatable {
    enum Paper: String, Codable, CaseIterable, Identifiable {
        case kraft, washi, linen, newsprint, indigo, sakura, matcha, basil, seigaiha, asanoha
        // English bookshops' papers.
        case brownpaper, ticking, pinstripe, awning, gingham, tartan, houndstooth, polka, harlequin, herringbone, chevron, graph, ledger, music, fleur, damask, sprig, stars, scales, ripple, ordnance, crossword, marbledpaper, trellis, quatrefoil, argyle, tissue, laid, airmail, windowpane
        var id: Self { self }

        /// The thirty English papers, for English books (which also use the ten above).
        static let english: [Paper] = [.brownpaper, .ticking, .pinstripe, .awning, .gingham, .tartan, .houndstooth, .polka, .harlequin, .herringbone, .chevron, .graph, .ledger, .music, .fleur, .damask, .sprig, .stars, .scales, .ripple, .ordnance, .crossword, .marbledpaper, .trellis, .quatrefoil, .argyle, .tissue, .laid, .airmail, .windowpane]
        var isEnglish: Bool { Self.english.contains(self) }

        var label: String {
            switch self {
            case .kraft: "Kraft"
            case .washi: "Washi"
            case .linen: "Linen"
            case .newsprint: "Newsprint"
            case .indigo: "Indigo"
            case .sakura: "Sakura"
            case .matcha: "Matcha"
            case .basil: "Basil"
            case .seigaiha: "Waves"
            case .asanoha: "Hemp leaf"
            case .brownpaper: "Brown Paper"
            case .ticking: "Ticking"
            case .pinstripe: "Pinstripe"
            case .awning: "Awning"
            case .gingham: "Gingham"
            case .tartan: "Tartan"
            case .houndstooth: "Houndstooth"
            case .polka: "Polka Dot"
            case .harlequin: "Harlequin"
            case .herringbone: "Herringbone"
            case .chevron: "Chevron"
            case .graph: "Graph Paper"
            case .ledger: "Ledger"
            case .music: "Music Paper"
            case .fleur: "Fleur-de-lis"
            case .damask: "Damask"
            case .sprig: "Sprig"
            case .stars: "Star Field"
            case .scales: "Scales"
            case .ripple: "Ripple"
            case .ordnance: "Ordnance Map"
            case .crossword: "Crossword"
            case .marbledpaper: "Marbled"
            case .trellis: "Trellis"
            case .quatrefoil: "Quatrefoil"
            case .argyle: "Argyle"
            case .tissue: "Tissue"
            case .laid: "Laid Paper"
            case .airmail: "Airmail"
            case .windowpane: "Windowpane"
            }
        }

        var base: String {
            switch self {
            case .kraft: "C4A07A"
            case .washi: "EFE7D6"
            case .linen: "D9D2C2"
            case .newsprint: "E4E0D6"
            case .indigo: "2D3A58"
            case .sakura: "EACACB"
            case .matcha: "A3AE83"
            case .basil: "5D7B4B"
            case .seigaiha: "ECE5D4"
            case .asanoha: "D6B878"
            case .brownpaper: "B98E5F"
            case .ticking: "F1ECDF"
            case .pinstripe: "2C3140"
            case .awning: "F2EBDC"
            case .gingham: "F4EFE4"
            case .tartan: "2F4A3A"
            case .houndstooth: "EDE6D6"
            case .polka: "B7322C"
            case .harlequin: "E8DCC4"
            case .herringbone: "D8CFBF"
            case .chevron: "F0E8D8"
            case .graph: "F3F1E8"
            case .ledger: "EFE9D2"
            case .music: "F2ECDC"
            case .fleur: "1F3B5C"
            case .damask: "7A2230"
            case .sprig: "F3ECE0"
            case .stars: "1C2541"
            case .scales: "6E8B8E"
            case .ripple: "E6ECEB"
            case .ordnance: "EFE8D6"
            case .crossword: "F5F2EA"
            case .marbledpaper: "E7DCC8"
            case .trellis: "EEF0E6"
            case .quatrefoil: "EFE5D2"
            case .argyle: "8E2F2A"
            case .tissue: "F1DCDD"
            case .laid: "EFE8D5"
            case .airmail: "F3F2EE"
            case .windowpane: "E9E2D2"
            }
        }

        var ink: String {
            switch self {
            case .indigo, .basil: "F3EEE2"
            case .sakura: "8E3B46"
            case .matcha: "3E4A2C"
            case .seigaiha: "2B4068"
            case .asanoha: "5A3A1E"
            case .brownpaper: "3B2A1E"
            case .ticking: "2B3F66"
            case .pinstripe: "E9E4D6"
            case .awning: "A8322D"
            case .gingham: "3E6F9E"
            case .tartan: "B03A2E"
            case .houndstooth: "2A2622"
            case .polka: "F3E9DA"
            case .harlequin: "6B2D3F"
            case .herringbone: "5A5148"
            case .chevron: "2F6B5E"
            case .graph: "6E95B8"
            case .ledger: "4E7A9A"
            case .music: "3A342C"
            case .fleur: "D6B35A"
            case .damask: "A6404F"
            case .sprig: "6E8B5A"
            case .stars: "E7D9A8"
            case .scales: "EAE4D5"
            case .ripple: "3F6F86"
            case .ordnance: "A0703E"
            case .crossword: "1E1C1A"
            case .marbledpaper: "6B3A2A"
            case .trellis: "4F7A55"
            case .quatrefoil: "9A6A22"
            case .argyle: "2F4F7F"
            case .tissue: "B98A90"
            case .laid: "B3A584"
            case .airmail: "C8352E"
            case .windowpane: "8E2F2A"
            default: "7A2E26"
            }
        }

        /// Plain papers are textured; patterned ones are printed all over in their ink, the way a
        /// bookshop prints its wrapping paper: 青海波 (waves) and 麻の葉 (hemp leaf).
        enum Texture { case speckle, fibers, weave, lines, waves, hemp, english }

        /// The real paper under it.
        var grain: Print.Grain {
            switch self {
            case .linen, .kraft, .brownpaper, .tartan, .herringbone, .ledger, .argyle, .laid: .laid
            case .washi, .sakura, .indigo, .tissue: .crinkle
            default: .tooth
            }
        }
        var texture: Texture {
            switch self {
            case .kraft, .basil, .matcha: .speckle
            case .washi, .indigo, .sakura: .fibers
            case .linen: .weave
            case .newsprint: .lines
            case .seigaiha: .waves
            case .asanoha: .hemp
            default: .english
            }
        }

        var defaultStamp: String { self == .basil ? "BASIL BOOKS · LES" : "BUNKO" }

        /// The stamp pad's ink: the paper's own, unless that would vanish into a busy print.
        var stampInk: String {
            switch self {
            case .houndstooth, .chevron: "B5362A"
            case .argyle, .damask: "EFE6D2"
            case .tartan: "E9D58E"
            case .polka: "2A1A16"
            case .marbledpaper: "15130F"
            default: ink
            }
        }
    }

    enum StampShape: String, Codable, CaseIterable, Identifiable {
        /// `seal` is a vermilion 朱印, pressed by hand, its letters in columns read right to left.
        case circle, square, seal, none
        var id: Self { self }
        var label: String { rawValue.capitalized }
    }

    /// How the seal sets its stamp: Japanese in columns read right to left, one per word when
    /// the words are short (文庫堂 本店), else split evenly into up to three columns of six;
    /// anything else in rows, one per word (BASIL / BOOKS / LES), at most three.
    static func sealLines(_ stamp: String) -> (lines: [String], vertical: Bool) {
        let words = stamp.uppercased()
            .replacingOccurrences(of: "·", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let vertical = stamp.unicodeScalars.contains {
            (0x3040...0x30FF).contains($0.value) || (0x3400...0x9FFF).contains($0.value) || (0xF900...0xFAFF).contains($0.value)
        }
        guard words.count > 3 || (vertical && words.contains { $0.count > 6 }) else { return (words, vertical) }
        if vertical {
            let letters = Array(words.joined().prefix(18))
            let count = (letters.count + 5) / 6
            let perColumn = (letters.count + count - 1) / count
            let columns = stride(from: 0, to: letters.count, by: perColumn).map {
                String(letters[$0..<min($0 + perColumn, letters.count)])
            }
            return (columns, true)
        }
        let perRow = (words.count + 2) / 3
        return (stride(from: 0, to: words.count, by: perRow).map { words[$0..<min($0 + perRow, words.count)].joined(separator: " ") }, false)
    }

    var paper = Paper.kraft
    /// Overrides the paper's colour (hex).
    var tint: String?
    var stamp = "BUNKO"
    var stampShape = StampShape.circle
    /// A paper title slip (題簽), so covered books can still be told apart on the shelf.
    var showsLabel = true
    /// Off shows the book's own cover: the paper slid off.
    var wrapped = true
    /// The kind of obi it wears when there's something to say; nil picks one by the book.
    var obi: ObiStyle?
    /// The publisher's cover under the paper; nil picks a house by the book (or its series).
    var house: House.Imprint?
    /// For an English book, one of the English houses chosen instead (`EnglishHouse.id`).
    var edition: String?

    init(paper: Paper = .kraft, stamp: String? = nil) {
        self.paper = paper
        self.stamp = stamp ?? paper.defaultStamp
    }

    var baseHex: String { tint ?? paper.base }

    /// A book nobody has dressed yet, in the paper of the bookshop it came from: its look's shop
    /// and paper (or the stamp of the OPDS shop it was downloaded from). A series matches.
    static func automatic(for book: Book, shopStamp: String? = nil) -> CoverStyle {
        let look = Look.of(book)
        let shop = look.shop(japanese: book.printsJapanese)
        var style = CoverStyle(paper: look.paper, stamp: shopStamp ?? shop.stamp)
        style.stampShape = shopStamp == nil ? shop.shape : .circle
        return style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paper = (try? c.decodeIfPresent(Paper.self, forKey: .paper)) ?? .kraft
        tint = try? c.decodeIfPresent(String.self, forKey: .tint)
        stamp = (try? c.decodeIfPresent(String.self, forKey: .stamp)) ?? paper.defaultStamp
        stampShape = (try? c.decodeIfPresent(StampShape.self, forKey: .stampShape)) ?? .circle
        showsLabel = (try? c.decodeIfPresent(Bool.self, forKey: .showsLabel)) ?? true
        wrapped = (try? c.decodeIfPresent(Bool.self, forKey: .wrapped)) ?? true
        obi = try? c.decodeIfPresent(ObiStyle.self, forKey: .obi)
        house = try? c.decodeIfPresent(House.Imprint.self, forKey: .house)
        edition = (try? c.decodeIfPresent(String.self, forKey: .edition)).flatMap { $0 }.flatMap { EnglishHouse.with(id: $0)?.id }
    }
}
