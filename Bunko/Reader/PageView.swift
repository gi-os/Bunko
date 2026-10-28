import CoreText
import UIKit

/// Everything one page needs to draw itself.
struct PageRender {
    enum Side { case left, right, single }

    /// The chapter's framesetter and this page's range in it: the same layout the paginator
    /// measured, so a page that starts mid-paragraph isn't indented again. nil: a blank page.
    var setter: CTFramesetter?
    var range: CFRange
    var vertical: Bool
    var paper: ReaderSettings.Paper
    var side: Side
    /// For a single page: which edge is the spine.
    var bindingOnRight: Bool
    /// How thick the stack of pages under the outer edge is, 0...1.
    var edgeFraction: CGFloat
    var showsEdges: Bool
    var header: String?
    var number: Int?

    var spineOnRight: Bool {
        switch side {
        case .left: true
        case .right: false
        case .single: bindingOnRight
        }
    }
}

/// One page of paper: grain, the shadow of the spine, the stacked edges of the pages beneath,
/// and the type.
final class PageView: UIView {
    var render: PageRender? { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
        isOpaque = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let render else { return }
        let size = bounds.size
        render.paper.color.setFill()
        ctx.fill(bounds)
        ctx.saveGState()
        ctx.setAlpha(render.paper.isDark ? 0.5 : 1)
        UIColor(patternImage: PaperGrain.tile).setFill()
        ctx.fill(bounds)
        ctx.restoreGState()

        drawGutter(ctx, size: size, render: render)
        if render.showsEdges { drawEdges(ctx, size: size, render: render) }

        guard let setter = render.setter else { return }
        let rect = PageGeometry.textRect(page: size, bindingOnRight: render.spineOnRight)
        let path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, render.range, path,
                                             Paginator.frameAttributes(vertical: render.vertical))
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()

        drawFolio(size: size, render: render)
    }

    /// The paper darkening into the spine.
    private func drawGutter(_ ctx: CGContext, size: CGSize, render: PageRender) {
        let width: CGFloat = render.side == .single ? 22 : 46
        let strength: CGFloat = render.paper.isDark ? 0.45 : (render.side == .single ? 0.10 : 0.20)
        let colors = [UIColor.black.withAlphaComponent(strength).cgColor,
                      UIColor.black.withAlphaComponent(strength * 0.35).cgColor,
                      UIColor.black.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 1]) else { return }
        let spineX = render.spineOnRight ? size.width : 0
        let endX = render.spineOnRight ? size.width - width : width
        ctx.drawLinearGradient(gradient, start: CGPoint(x: spineX, y: 0), end: CGPoint(x: endX, y: 0), options: [])
    }

    /// Thin lines at the outer edge: the leaves of the rest of the book.
    private func drawEdges(_ ctx: CGContext, size: CGSize, render: PageRender) {
        let thickness = 1.5 + 7 * min(max(render.edgeFraction, 0), 1)
        let leaves = Int(thickness / 1.5)
        let outerOnRight = !render.spineOnRight
        let line = render.paper.ink.withAlphaComponent(render.paper.isDark ? 0.35 : 0.12)
        line.setFill()
        for leaf in 0...leaves {
            let inset = CGFloat(leaf) * 1.5
            let x = outerOnRight ? size.width - inset - 0.5 : inset
            ctx.fill(CGRect(x: x, y: 0, width: 0.5, height: size.height))
        }
    }

    /// The running head (柱) and page number (ノンブル), on the outer side.
    private func drawFolio(size: CGSize, render: PageRender) {
        let m = PageGeometry.margins(page: size)
        let outerOnRight = !render.spineOnRight
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Typesetter.font(.mincho, size: 10),
            .foregroundColor: render.paper.faint,
        ]
        let edge: CGFloat = 34
        if let header = render.header, !header.isEmpty {
            let maxWidth = size.width * 0.38
            let text = NSString(string: header)
            var box = text.boundingRect(with: CGSize(width: maxWidth, height: 14), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs, context: nil)
            box.size.width = min(box.width, maxWidth)
            let x = outerOnRight ? size.width - edge - box.width : edge
            text.draw(with: CGRect(x: x, y: m.top * 0.5, width: box.width, height: 14),
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs, context: nil)
        }
        if let number = render.number {
            let text = NSString(string: "\(number)")
            let width = text.size(withAttributes: attrs).width
            let x = outerOnRight ? size.width - edge - width : edge
            text.draw(at: CGPoint(x: x, y: size.height - m.bottom * 0.55), withAttributes: attrs)
        }
    }
}

/// A page (or, sliding, a whole spread) as the page turner's unit.
final class UnitController: UIViewController {
    let unit: Int
    private let pages: [(page: Int, side: PageRender.Side)]
    private let pageViews: [PageView]

    init(unit: Int, pages: [(page: Int, side: PageRender.Side)], model: ReaderModel) {
        self.unit = unit
        self.pages = pages
        pageViews = pages.map { _ in PageView(frame: .zero) }
        super.init(nibName: nil, bundle: nil)
        refresh(with: model)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func refresh(with model: ReaderModel) {
        for (view, page) in zip(pageViews, pages) { view.render = model.render(page: page.page, side: page.side) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = UIStackView(arrangedSubviews: pageViews)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.frame = view.bounds
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stack)
    }
}
