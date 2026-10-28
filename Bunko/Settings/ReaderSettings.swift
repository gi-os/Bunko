import CoreGraphics
import Foundation

/// How pages look and turn. Synced through iCloud, so every field decodes with a default: an
/// older copy from another device (missing newer fields) still loads.
struct ReaderSettings: Codable, Equatable {
    enum Typeface: String, Codable, CaseIterable, Identifiable {
        case mincho, gothic, serif
        var id: Self { self }
        var label: String {
            switch self {
            case .mincho: "Mincho 明朝"
            case .gothic: "Gothic ゴシック"
            case .serif: "Old Style"
            }
        }
    }

    enum Direction: String, Codable, CaseIterable, Identifiable {
        case auto, vertical, horizontal
        var id: Self { self }
        var label: String {
            switch self {
            case .auto: "Follow the book"
            case .vertical: "Vertical 縦書き"
            case .horizontal: "Horizontal 横書き"
            }
        }
    }

    enum Paper: String, Codable, CaseIterable, Identifiable {
        case white, cream, aged, night
        var id: Self { self }
        var label: String { rawValue.capitalized }
    }

    enum Turn: String, Codable, CaseIterable, Identifiable {
        case curl, slide
        var id: Self { self }
        var label: String { self == .curl ? "Page curl" : "Slide" }
    }

    enum Spread: String, Codable, CaseIterable, Identifiable {
        case auto, always, never
        var id: Self { self }
        var label: String {
            switch self {
            case .auto: "On wide screens"
            case .always: "Always"
            case .never: "Never"
            }
        }
    }

    var typeface = Typeface.mincho
    var fontSize: Double = 17
    /// Extra space between lines, as a fraction of the font size.
    var lineSpacing: Double = 0.65
    var direction = Direction.auto
    var paper = Paper.cream
    var turn = Turn.curl
    var spread = Spread.auto
    var ribbonColor = "A8322D"
    var showsPageEdges = true
    var showsHeader = true
    var haptics = true

    /// Width (points) from which "On wide screens" opens the book as a two-page spread: the
    /// iPhone Duo unfolded, or any iPhone on its side.
    static let spreadWidth: CGFloat = 600

    init() {}

    func usesSpread(in size: CGSize) -> Bool {
        switch spread {
        case .always: true
        case .never: false
        case .auto: size.width >= Self.spreadWidth
        }
    }

    func isVertical(for book: Book) -> Bool {
        switch direction {
        case .auto: book.rightToLeft
        case .vertical: true
        case .horizontal: false
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReaderSettings()
        typeface = (try? c.decodeIfPresent(Typeface.self, forKey: .typeface)) ?? d.typeface
        fontSize = (try? c.decodeIfPresent(Double.self, forKey: .fontSize)) ?? d.fontSize
        lineSpacing = (try? c.decodeIfPresent(Double.self, forKey: .lineSpacing)) ?? d.lineSpacing
        direction = (try? c.decodeIfPresent(Direction.self, forKey: .direction)) ?? d.direction
        paper = (try? c.decodeIfPresent(Paper.self, forKey: .paper)) ?? d.paper
        turn = (try? c.decodeIfPresent(Turn.self, forKey: .turn)) ?? d.turn
        spread = (try? c.decodeIfPresent(Spread.self, forKey: .spread)) ?? d.spread
        ribbonColor = (try? c.decodeIfPresent(String.self, forKey: .ribbonColor)) ?? d.ribbonColor
        showsPageEdges = (try? c.decodeIfPresent(Bool.self, forKey: .showsPageEdges)) ?? d.showsPageEdges
        showsHeader = (try? c.decodeIfPresent(Bool.self, forKey: .showsHeader)) ?? d.showsHeader
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? d.haptics
    }
}
