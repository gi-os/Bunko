import Foundation

/// A bookshop paper cover (書店カバー) wrapped around a book. Synced through iCloud.
struct CoverStyle: Codable, Equatable {
    enum Paper: String, Codable, CaseIterable, Identifiable {
        case kraft, washi, linen, newsprint, indigo, sakura, matcha, basil
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
            }
        }

        var ink: String {
            switch self {
            case .indigo, .basil: "F3EEE2"
            case .sakura: "8E3B46"
            case .matcha: "3E4A2C"
            default: "7A2E26"
            }
        }

        enum Texture { case speckle, fibers, weave, lines }
        var texture: Texture {
            switch self {
            case .kraft, .basil, .matcha: .speckle
            case .washi, .indigo, .sakura: .fibers
            case .linen: .weave
            case .newsprint: .lines
            }
        }

        var defaultStamp: String { self == .basil ? "BASIL BOOKS · LES" : "BUNKO" }
    }

    enum StampShape: String, Codable, CaseIterable, Identifiable {
        case circle, square, none
        var id: Self { self }
        var label: String { rawValue.capitalized }
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
    }
}
