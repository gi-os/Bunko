import SwiftUI

/// Printing, not drawing: what makes a cover look like ink on paper rather than shapes on glass.
/// Ink doesn't take evenly (it mottles and leaves pinholes where the paper shows), paper has
/// fibres in it, and light falls across a book in your hands unevenly.
enum Print {
    /// Real paper, scanned (CC0, ambientCG; Resources/Textures): the grain maps sit at 50% grey so
    /// soft light gives any colour the paper's tooth without changing it.
    enum Grain: CaseIterable {
        /// Smooth stock: a fine tooth and the odd fleck.
        case tooth
        /// Laid, ribbed paper: fine lines in one direction.
        case laid
        /// Soft, handled paper (washi): long low creases.
        case crinkle

        var image: UIImage { Print.texture(file) }
        private var file: String {
            switch self {
            case .tooth: "grain-tooth"
            case .laid: "grain-laid"
            case .crinkle: "grain-crinkle"
            }
        }
    }

    /// The bookshop's own kraft wrapping paper, scanned in colour.
    static var kraft: UIImage { texture("kraft-ribbed") }

    private static var cache: [String: UIImage] = [:]
    static func texture(_ name: String) -> UIImage {
        if let image = cache[name] { return image }
        let image = Bundle.main.path(forResource: name, ofType: "jpg").flatMap(UIImage.init(contentsOfFile:)) ?? UIImage()
        cache[name] = image
        return image
    }

    /// The scan's tile width, as a share of the cover's: real paper's grain is the same size on a
    /// thumbnail of the book as on the book itself.
    static func tileScale(coverWidth: CGFloat) -> CGFloat { max(coverWidth, 1) / 360 }

    /// Fine light specks, screened over a print: where the ink didn't quite take, the paper shows.
    /// The dark ink breaks up a little; the pale paper hardly changes.
    static let mottle: UIImage = tile(seed: 0x1_4C0) { ctx, size, rng in
        for _ in 0..<9000 {
            let r = CGFloat.random(in: 0.2...0.6, using: &rng)
            UIColor.white.withAlphaComponent(.random(in: 0.08...0.32, using: &rng)).setFill()
            ctx.fillEllipse(in: CGRect(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng),
                                       width: r, height: r * .random(in: 0.6...1.4, using: &rng)))
        }
    }

    private static func tile(seed: UInt64, draw: (CGContext, CGSize, inout SeededRandom) -> Void) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        var rng = SeededRandom(seed: seed)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext, size, &rng) }
    }
}

extension View {
    /// Ink on paper: the paper's real grain through everything, the ink thin in places, the light
    /// falling unevenly across it. `strength` lowers it for small thumbnails, where grain would
    /// read as dirt.
    func printed(strength: Double = 1, grain: Print.Grain = .tooth) -> some View {
        self
            // Print is never razor sharp: the ink spreads a hair into the paper.
            .blur(radius: 0.3 * strength)
            .overlay(Image(uiImage: Print.mottle).resizable(resizingMode: .tile).blendMode(.screen).opacity(0.6 * strength)
                .allowsHitTesting(false))
            .overlay(
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .tiledImage(Image(uiImage: grain.image), scale: Print.tileScale(coverWidth: size.width)))
                }
                .blendMode(.softLight)
                .opacity(strength)
                .allowsHitTesting(false)
            )
            .overlay(
                LinearGradient(stops: [.init(color: .white.opacity(0.10), location: 0), .init(color: .clear, location: 0.45),
                                       .init(color: .black.opacity(0.10), location: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
            )
            .compositingGroup()
    }
}
