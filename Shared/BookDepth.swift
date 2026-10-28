import SwiftUI

/// A book is not a sheet of paper. Seen a little from the fore-edge and the foot, the page block
/// shows past the cover: every leaf a hairline, and beyond the last one the back board's edge.
/// Drawn in the whole book's frame, with the cover filling all but `depth` at the fore-edge
/// and the foot.
struct PageBlock: View {
    /// The spine's side; the block shows on the other side (the fore-edge) and along the foot.
    let spineOnRight: Bool
    /// How much of it shows, in points.
    let depth: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let d = depth
            let cover = CGSize(width: size.width - d, height: size.height - d)
            // Leaf `t` deep is the cover's outline moved t toward the fore-edge and t down.
            func leaf(_ t: CGFloat) -> CGRect {
                CGRect(x: spineOnRight ? d - t : t, y: t, width: cover.width, height: cover.height)
            }
            func edges(_ r: CGRect) -> Path {
                var path = Path()
                let foreX = spineOnRight ? r.minX : r.maxX
                path.move(to: CGPoint(x: foreX, y: r.minY))
                path.addLine(to: CGPoint(x: foreX, y: r.maxY))
                path.addLine(to: CGPoint(x: spineOnRight ? r.maxX : r.minX, y: r.maxY))
                return path
            }
            // The block: everything the leaves cover that the front cover doesn't.
            var block = Path()
            for t in stride(from: 0, through: d, by: max(0.5, d / 12)) { block.addRect(leaf(t)) }
            ctx.fill(block, with: .color(Color(hex: "EFE7D4")))
            ctx.fill(block, with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.12)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var t: CGFloat = 0.7
            var light = false
            while t < d - 1 {
                ctx.stroke(edges(leaf(t)), with: .color(.black.opacity(light ? 0.06 : 0.13)), lineWidth: 0.5)
                light.toggle()
                t += 0.9
            }
            // The back board, a hair beyond the last leaf.
            ctx.stroke(edges(leaf(d - 0.6)), with: .color(Color(hex: "4A4038")), lineWidth: 1.2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Gives a cover-sized view the depth of a book: its page block showing past the fore-edge
    /// and the foot.
    func bookDepth(spineOnRight: Bool, depth: CGFloat) -> some View {
        background {
            PageBlock(spineOnRight: spineOnRight, depth: depth)
                .padding(spineOnRight ? .leading : .trailing, -depth)
                .padding(.bottom, -depth)
        }
    }
}
