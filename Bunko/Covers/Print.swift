import SwiftUI

/// Printing, not drawing: what makes a cover look like ink on paper rather than shapes on glass.
/// Ink doesn't take evenly (it mottles and leaves pinholes where the paper shows), paper has
/// fibres in it, and light falls across a book in your hands unevenly.
enum Print {
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

    /// Short fibres, light and dark, and a fine tooth: multiplied over everything.
    static let fibres: UIImage = tile(seed: 0xF1_BE5) { ctx, size, rng in
        for _ in 0..<2600 {
            let dark = Bool.random(using: &rng)
            (dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.97, alpha: 1))
                .withAlphaComponent(.random(in: 0.08...0.22, using: &rng)).setFill()
            let r = CGFloat.random(in: 0.3...0.8, using: &rng)
            ctx.fillEllipse(in: CGRect(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng), width: r, height: r))
        }
        ctx.setLineCap(.round)
        for _ in 0..<260 {
            let start = CGPoint(x: .random(in: 0..<size.width, using: &rng), y: .random(in: 0..<size.height, using: &rng))
            let length = CGFloat.random(in: 3...11, using: &rng), angle = CGFloat.random(in: 0..<(.pi * 2), using: &rng)
            ctx.setStrokeColor(UIColor(white: .random(in: 0.5...0.75, using: &rng), alpha: .random(in: 0.12...0.3, using: &rng)).cgColor)
            ctx.setLineWidth(.random(in: 0.25...0.5, using: &rng))
            ctx.move(to: start)
            ctx.addQuadCurve(to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length),
                             control: CGPoint(x: start.x + cos(angle + 0.5) * length * 0.5, y: start.y + sin(angle + 0.5) * length * 0.5))
            ctx.strokePath()
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
    /// Ink on paper: the ink mottled, fibres through it all, the light falling unevenly across it.
    /// `strength` lowers it for small thumbnails, where the grain would read as dirt.
    func printed(strength: Double = 1) -> some View {
        self
            // Print is never razor sharp: the ink spreads a hair into the paper.
            .blur(radius: 0.3 * strength)
            .overlay(Image(uiImage: Print.mottle).resizable(resizingMode: .tile).blendMode(.screen).opacity(0.7 * strength)
                .allowsHitTesting(false))
            .overlay(Image(uiImage: Print.fibres).resizable(resizingMode: .tile).blendMode(.multiply).opacity(0.9 * strength)
                .allowsHitTesting(false))
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
