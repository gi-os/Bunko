import Foundation

/// A bookshop paper cover (書店カバー) wrapped around a book. Synced through iCloud.
struct CoverStyle: Codable, Equatable {
    enum Paper: String, Codable, CaseIterable, Identifiable {
        case kraft, washi, linen, newsprint, indigo, sakura, matcha, basil, seigaiha, asanoha
        var id: Self { self }

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
            }
        }

        var ink: String {
            switch self {
            case .indigo, .basil: "F3EEE2"
            case .sakura: "8E3B46"
            case .matcha: "3E4A2C"
            case .seigaiha: "2B4068"
            case .asanoha: "5A3A1E"
            default: "7A2E26"
            }
        }

        /// Plain papers are textured; patterned ones are printed all over in their ink, the way a
        /// bookshop prints its wrapping paper: 青海波 (waves) and 麻の葉 (hemp leaf).
        enum Texture { case speckle, fibers, weave, lines, waves, hemp }
        var texture: Texture {
            switch self {
            case .kraft, .basil, .matcha: .speckle
            case .washi, .indigo, .sakura: .fibers
            case .linen: .weave
            case .newsprint: .lines
            case .seigaiha: .waves
            case .asanoha: .hemp
            }
        }

        var defaultStamp: String { self == .basil ? "BASIL BOOKS · LES" : "BUNKO" }
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

    init(paper: Paper = .kraft, stamp: String? = nil) {
        self.paper = paper
        self.stamp = stamp ?? paper.defaultStamp
    }

    var baseHex: String { tint ?? paper.base }

    /// A book nobody has dressed yet: everyday papers picked by the book's ID, so the shelf
    /// looks varied but each book keeps its paper.
    static func automatic(for book: Book, shopStamp: String? = nil) -> CoverStyle {
        let everyday: [Paper] = [.kraft, .washi, .linen, .newsprint]
        let pick = book.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % everyday.count
        return CoverStyle(paper: everyday[pick], stamp: shopStamp)
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
    }
}
