import SwiftUI
import UIKit

extension ReaderSettings.Paper {
    var color: UIColor {
        switch self {
        case .white: UIColor(hex: "FAF9F5")
        case .cream: UIColor(hex: "F3ECDC")
        case .aged: UIColor(hex: "E8DCC2")
        case .night: UIColor(hex: "1D1B18")
        }
    }

    var ink: UIColor {
        self == .night ? UIColor(hex: "CFC5B2") : UIColor(hex: "29241F")
    }

    /// Page edges and the header: a quieter ink.
    var faint: UIColor { ink.withAlphaComponent(0.45) }

    var isDark: Bool { self == .night }
}

/// A fine paper grain, drawn once and tiled over every page.
enum PaperGrain {
    static let tile: UIImage = {
        let size = CGSize(width: 160, height: 160)
        var rng = SeededRandom(seed: 0xB0_4C0)
        return UIGraphicsImageRenderer(size: size).image { context in
            for _ in 0..<1400 {
                let x = CGFloat.random(in: 0..<size.width, using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let dark = Bool.random(using: &rng)
                (dark ? UIColor.black : UIColor.white).withAlphaComponent(.random(in: 0.025...0.07, using: &rng)).setFill()
                let r = CGFloat.random(in: 0.4...1.1, using: &rng)
                context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }()
}

/// The same "random" texture every time for the same seed (paper covers keep their speckles).
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    init(string: String) {
        self.init(seed: string.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
