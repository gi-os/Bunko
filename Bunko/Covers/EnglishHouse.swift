import SwiftUI

/// The English publishers' houses: forty-five of them, three for each of fifteen ways a book's
/// cover has been printed or bound in English: bands, bookcloth and foil, patterned paper boards,
/// marbling, letterpress, linocut, wood engraving, two-colour offset, halftone, screen printing,
/// pulp, deckle-edged wrappers, art deco, Swiss typography and risograph. An English book draws its
/// house from these and from the fifteen Japanese houses in their English editions.
struct EnglishHouse: Identifiable, Hashable {
    enum Technique: String, CaseIterable {
        case bands, cloth, boards, marbled, letterpress, linocut, engraving, overprint, halftone, screenprint,
             pulp, deckle, deco, swiss, riso
    }

    /// Real faces, as the iOS type library has them.
    enum Face: String, CaseIterable {
        case gill, futura, helvetica, condensed, baskerville, bodoni, didot, rockwell, clarendon, copperplate,
             typewriter, optima, palatino, iowan, script, cochin, hoefler

        var names: (regular: String, bold: String) {
            switch self {
            case .gill: ("GillSans", "GillSans-SemiBold")
            case .futura: ("Futura-Medium", "Futura-Bold")
            case .helvetica: ("HelveticaNeue", "HelveticaNeue-Bold")
            case .condensed: ("HelveticaNeue-CondensedBold", "HelveticaNeue-CondensedBlack")
            case .baskerville: ("Baskerville", "Baskerville-SemiBold")
            case .bodoni: ("BodoniSvtyTwoITCTT-Book", "BodoniSvtyTwoITCTT-Bold")
            case .didot: ("Didot", "Didot-Bold")
            case .rockwell: ("Rockwell-Regular", "Rockwell-Bold")
            case .clarendon: ("Superclarendon-Regular", "Superclarendon-Black")
            case .copperplate: ("Copperplate", "Copperplate-Bold")
            case .typewriter: ("AmericanTypewriter", "AmericanTypewriter-Bold")
            case .optima: ("Optima-Regular", "Optima-Bold")
            case .palatino: ("Palatino-Roman", "Palatino-Bold")
            case .iowan: ("IowanOldStyle-Roman", "IowanOldStyle-Bold")
            case .script: ("SnellRoundhand", "SnellRoundhand-Bold")
            case .cochin: ("Cochin", "Cochin-Bold")
            case .hoefler: ("HoeflerText-Regular", "HoeflerText-Black")
            }
        }

        func font(size: CGFloat, bold: Bool = false) -> Font {
            .custom(bold ? names.bold : names.regular, fixedSize: size)
        }

        func uiFont(size: CGFloat, bold: Bool = false) -> UIFont {
            UIFont(name: bold ? names.bold : names.regular, size: size) ?? .systemFont(ofSize: size)
        }
    }

    enum Foil: String {
        case none, gold, silver, copper

        /// Foil catches the light: a gradient across it.
        var colours: [Color] {
            let hex: [String]
            switch self {
            case .gold, .none: hex = ["9C7A2E", "E9D58E", "B8933F", "F3E6B0", "8E6E28"]
            case .silver: hex = ["7D8086", "E6E8EB", "A5A9AF", "F5F6F7", "6E7177"]
            case .copper: hex = ["8A4B2C", "E3A07A", "A8623E", "F0C3A4", "7A3F24"]
            }
            return hex.map { Color(hex: $0) }
        }
    }

    enum Rules: String { case none, single, double, heavy }

    let id: String
    let name: String
    /// The house's mark in the ring: a letter, a monogram.
    let colophon: String
    let technique: Technique
    /// Which of its technique's three compositions.
    let composition: Int
    let face: Face
    /// The paper or cloth.
    let stock: String
    /// A fixed ink; nil prints in the book's colour.
    let ink: String?
    let ornament: String?
    let foil: Foil
    let rules: Rules
    /// What it is, for the cover editor.
    let summary: String

    static func with(id: String) -> EnglishHouse? { all.first { $0.id == id } }

    // swiftlint:disable line_length
    static let all: [EnglishHouse] = [
        // Bands: the paperback's colour-coded bands.
        .init(id: "kittiwake", name: "Kittiwake Books", colophon: "K", technique: .bands, composition: 0, face: .gill, stock: "F4EFE2", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Three bands"),
        .init(id: "cormorant", name: "Cormorant Paperbacks", colophon: "CP", technique: .bands, composition: 1, face: .futura, stock: "F1ECDD", ink: nil, ornament: nil, foil: .none, rules: .double, summary: "Centre band"),
        .init(id: "albatross", name: "Albatross Modern", colophon: "A", technique: .bands, composition: 2, face: .bodoni, stock: "F3EEE1", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Colour border"),
        // Bookcloth and foil.
        .init(id: "commonplace", name: "Commonplace Library", colophon: "CL", technique: .cloth, composition: 0, face: .baskerville, stock: "2B2622", ink: nil, ornament: "❧", foil: .gold, rules: .double, summary: "Gold on cloth"),
        .init(id: "vellum", name: "Vellum & Thread", colophon: "VT", technique: .cloth, composition: 1, face: .hoefler, stock: "D6CBB2", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Linen, pasted label"),
        .init(id: "giltedge", name: "Gilt Edge Library", colophon: "GE", technique: .cloth, composition: 2, face: .didot, stock: "3A2F2A", ink: nil, ornament: "✦", foil: .silver, rules: .heavy, summary: "Gilt rules"),
        // Patterned paper boards with a label.
        .init(id: "isola", name: "Isola Books", colophon: "IB", technique: .boards, composition: 0, face: .bodoni, stock: "EFE6D2", ink: nil, ornament: "❖", foil: .none, rules: .double, summary: "Patterned boards"),
        .init(id: "wren", name: "Wren Library", colophon: "W", technique: .boards, composition: 1, face: .cochin, stock: "F2EADB", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Striped boards"),
        .init(id: "juniper", name: "Juniper Press", colophon: "J", technique: .boards, composition: 2, face: .palatino, stock: "ECE3CF", ink: nil, ornament: "◆", foil: .none, rules: .double, summary: "Lattice boards"),
        // Marbling.
        .init(id: "marbledleaf", name: "Marbled Leaf", colophon: "ML", technique: .marbled, composition: 0, face: .hoefler, stock: "EFE6D3", ink: nil, ornament: nil, foil: .gold, rules: .single, summary: "Marbled, leather spine"),
        .init(id: "nautilus", name: "Paper Nautilus", colophon: "PN", technique: .marbled, composition: 1, face: .cochin, stock: "F1EADA", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Marbled panel"),
        .init(id: "oxbow", name: "Oxbow Editions", colophon: "OX", technique: .marbled, composition: 2, face: .baskerville, stock: "F3ECDD", ink: nil, ornament: nil, foil: .none, rules: .double, summary: "Marbled border"),
        // Letterpress.
        .init(id: "quill", name: "Quill & Press", colophon: "Q", technique: .letterpress, composition: 0, face: .iowan, stock: "F3EEE2", ink: "26221D", ornament: "❦", foil: .none, rules: .double, summary: "Title page"),
        .init(id: "northgate", name: "Northgate Press", colophon: "N", technique: .letterpress, composition: 1, face: .condensed, stock: "EFE7D4", ink: "1F1C19", ornament: nil, foil: .none, rules: .heavy, summary: "Wood type"),
        .init(id: "caxton", name: "Caxton Row", colophon: "CR", technique: .letterpress, composition: 2, face: .baskerville, stock: "F4EFE3", ink: "26221D", ornament: "❀", foil: .none, rules: .none, summary: "Flower border"),
        // Linocut.
        .init(id: "rook", name: "Rook Books", colophon: "R", technique: .linocut, composition: 0, face: .gill, stock: "F2ECDD", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Linocut landscape"),
        .init(id: "hollowoak", name: "Hollow Oak", colophon: "HO", technique: .linocut, composition: 1, face: .rockwell, stock: "EFE7D6", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Linocut moon"),
        .init(id: "yarrow", name: "Yarrow Press", colophon: "Y", technique: .linocut, composition: 2, face: .futura, stock: "F1EBDD", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Linocut waves"),
        // Wood and copper engraving.
        .init(id: "copperleaf", name: "Copperleaf Classics", colophon: "CC", technique: .engraving, composition: 0, face: .copperplate, stock: "F2EDE0", ink: nil, ornament: nil, foil: .none, rules: .double, summary: "Engraved vignette"),
        .init(id: "bewick", name: "Bewick House", colophon: "BH", technique: .engraving, composition: 1, face: .palatino, stock: "F0EADB", ink: nil, ornament: "✠", foil: .none, rules: .double, summary: "Engraved border"),
        .init(id: "burin", name: "Burin Books", colophon: "BU", technique: .engraving, composition: 2, face: .didot, stock: "EEE9DC", ink: nil, ornament: nil, foil: .none, rules: .single, summary: "Guilloché"),
        // Two-colour offset, overprinted.
        .init(id: "vector", name: "Vector Books", colophon: "V", technique: .overprint, composition: 0, face: .futura, stock: "F3EEE1", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Circle and bar"),
        .init(id: "kinetic", name: "Kinetic Library", colophon: "KL", technique: .overprint, composition: 1, face: .helvetica, stock: "F1ECE0", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Overprinted arcs"),
        .init(id: "prism", name: "Prism Paperbacks", colophon: "PP", technique: .overprint, composition: 2, face: .gill, stock: "F5F1E6", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Three inks"),
        // Halftone.
        .init(id: "tidewater", name: "Tidewater Books", colophon: "TW", technique: .halftone, composition: 0, face: .helvetica, stock: "F3EFE4", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Halftone sky"),
        .init(id: "signal", name: "Signal Paperbacks", colophon: "SG", technique: .halftone, composition: 1, face: .futura, stock: "F2EDE2", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Halftone sweep"),
        .init(id: "nightjar", name: "Nightjar Books", colophon: "NJ", technique: .halftone, composition: 2, face: .condensed, stock: "F4EFE3", ink: nil, ornament: nil, foil: .none, rules: .heavy, summary: "Ben-Day dots"),
        // Screen printing.
        .init(id: "papermoon", name: "Paper Moon Press", colophon: "PM", technique: .screenprint, composition: 0, face: .condensed, stock: "EFE8D7", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Moon and sea"),
        .init(id: "fairground", name: "Fairground Books", colophon: "FG", technique: .screenprint, composition: 1, face: .clarendon, stock: "F3ECDB", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Big initial"),
        .init(id: "lanternslide", name: "Lantern Slide", colophon: "LS", technique: .screenprint, composition: 2, face: .futura, stock: "F1E9D6", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Rays"),
        // Pulp.
        .init(id: "thrilling", name: "Thrilling Tales", colophon: "TT", technique: .pulp, composition: 0, face: .rockwell, stock: "E6DAB4", ink: "1D1A17", ornament: nil, foil: .none, rules: .none, summary: "Pulp banner"),
        .init(id: "dime", name: "Dime Library", colophon: "DL", technique: .pulp, composition: 1, face: .condensed, stock: "E9DDB8", ink: "1D1A17", ornament: nil, foil: .none, rules: .none, summary: "Pulp split"),
        .init(id: "midnight", name: "Midnight Mysteries", colophon: "MM", technique: .pulp, composition: 2, face: .clarendon, stock: "E4D8B2", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Pulp spotlight"),
        // Deckle-edged wrappers.
        .init(id: "ragpaper", name: "Rag Paper Press", colophon: "RP", technique: .deckle, composition: 0, face: .baskerville, stock: "F1EBDC", ink: "2A251F", ornament: "❦", foil: .none, rules: .single, summary: "Deckle wrapper"),
        .init(id: "fieldfare", name: "Fieldfare Editions", colophon: "FE", technique: .deckle, composition: 1, face: .script, stock: "ECE4D1", ink: "2A251F", ornament: nil, foil: .none, rules: .single, summary: "Handmade, label"),
        .init(id: "hedgerow", name: "Hedgerow Books", colophon: "HB", technique: .deckle, composition: 2, face: .iowan, stock: "F0E9D8", ink: "2A251F", ornament: nil, foil: .none, rules: .none, summary: "Plate mark"),
        // Art deco.
        .init(id: "meridian", name: "Meridian Books", colophon: "MB", technique: .deco, composition: 0, face: .didot, stock: "1E1D22", ink: nil, ornament: nil, foil: .gold, rules: .double, summary: "Sunburst"),
        .init(id: "skyline", name: "Skyline Library", colophon: "SK", technique: .deco, composition: 1, face: .futura, stock: "1C2027", ink: nil, ornament: nil, foil: .silver, rules: .single, summary: "Ziggurat"),
        .init(id: "odeon", name: "Odeon Editions", colophon: "OD", technique: .deco, composition: 2, face: .bodoni, stock: "22191A", ink: nil, ornament: nil, foil: .copper, rules: .double, summary: "Fan"),
        // Swiss typography.
        .init(id: "zurich", name: "Zurich Paperbacks", colophon: "Z", technique: .swiss, composition: 0, face: .helvetica, stock: "F4F1EA", ink: "1C1B1A", ornament: nil, foil: .none, rules: .single, summary: "Grid and block"),
        .init(id: "ulm", name: "Ulm Library", colophon: "U", technique: .swiss, composition: 1, face: .helvetica, stock: "F2EFE8", ink: "1C1B1A", ornament: nil, foil: .none, rules: .none, summary: "Three bars"),
        .init(id: "grid", name: "Grid Editions", colophon: "GD", technique: .swiss, composition: 2, face: .optima, stock: "F3F0E7", ink: "1C1B1A", ornament: nil, foil: .none, rules: .single, summary: "Modular grid"),
        // Risograph.
        .init(id: "fluoro", name: "Fluoro Press", colophon: "FL", technique: .riso, composition: 0, face: .futura, stock: "F4F0E6", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Pink and blue"),
        .init(id: "duplicator", name: "Duplicator Books", colophon: "DU", technique: .riso, composition: 1, face: .gill, stock: "F3EFE5", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Riso gradient"),
        .init(id: "stencil", name: "Stencil & Drum", colophon: "SD", technique: .riso, composition: 2, face: .condensed, stock: "F2EEE3", ink: nil, ornament: nil, foil: .none, rules: .none, summary: "Riso type"),
    ]
    // swiftlint:enable line_length

    /// A second ink to go with the book's colour, for the two-colour houses.
    static func second(to colour: String, variant: Int) -> String {
        let palette = Look.colours
        let index = palette.firstIndex(of: colour) ?? 0
        return palette[(index + 5 + variant * 3) % palette.count]
    }
}

/// What a spine needs to look like its English house's cover.
struct SpineRecipe: Equatable {
    enum Texture: Equatable { case paper, laid, cloth, pulp, marbled, pattern(String) }
    /// A band across the spine, as shares of its height from the head.
    struct Band: Equatable {
        var from: CGFloat
        var to: CGFloat
        var colour: String
    }

    var stock: String
    var texture: Texture
    var bands: [Band]
    var rules: EnglishHouse.Rules
    var ornament: String?
    var foil: EnglishHouse.Foil
    var face: EnglishHouse.Face
    var ink: String
    var name: String
    var colophon: String
}

extension EnglishHouse {
    /// The spine to go with a cover in `colour`, in layout `variant`.
    func spine(colour: String, variant: Int) -> SpineRecipe {
        let second = Self.second(to: colour, variant: variant)
        let dark = ink ?? "26221D"
        var recipe = SpineRecipe(stock: stock, texture: .paper, bands: [], rules: rules, ornament: ornament, foil: foil,
                                 face: face, ink: colour, name: name, colophon: colophon)
        switch technique {
        case .bands:
            recipe.bands = composition == 0 ? [.init(from: 0, to: 0.26, colour: colour), .init(from: 0.74, to: 1, colour: colour)]
                : composition == 1 ? [.init(from: 0.36, to: 0.62, colour: colour)]
                : [.init(from: 0, to: 1, colour: colour)]
            recipe.ink = composition == 2 ? stock : dark
        case .cloth:
            recipe.texture = .cloth
            recipe.stock = composition == 1 ? stock : colour
            recipe.ink = composition == 1 ? colour : stock
        case .boards:
            recipe.texture = .pattern(ornament ?? "|")
            recipe.ink = dark
        case .marbled:
            recipe.texture = .marbled
            recipe.stock = composition == 0 ? "5A3A28" : stock
            recipe.ink = composition == 0 ? "E9D58E" : dark
        case .letterpress, .deckle:
            recipe.texture = .laid
            recipe.ink = dark
        case .linocut, .screenprint:
            recipe.bands = [.init(from: 0, to: 0.62, colour: colour)]
            recipe.ink = dark
        case .engraving:
            recipe.ink = colour
        case .overprint, .riso:
            recipe.bands = [.init(from: 0.08, to: 0.3, colour: colour), .init(from: 0.22, to: 0.44, colour: second)]
            recipe.ink = dark
        case .halftone:
            recipe.bands = [.init(from: 0, to: 0.5, colour: colour)]
            recipe.ink = dark
        case .pulp:
            recipe.texture = .pulp
            recipe.bands = [.init(from: 0, to: 0.7, colour: composition == 2 ? "15130F" : colour)]
            recipe.ink = composition == 2 ? colour : dark
        case .deco:
            recipe.stock = stock
            recipe.ink = stock
        case .swiss:
            recipe.bands = [.init(from: 0, to: 0.4, colour: colour)]
            recipe.ink = dark
        }
        return recipe
    }
}
