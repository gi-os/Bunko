import CoreGraphics

/// How pages sit on the screen: one page, or an open book of two. A right-to-left book (vertical
/// Japanese) puts the earlier page on the right and is bound on the right.
struct SpreadLayout: Equatable {
    var pageCount: Int
    var spread: Bool
    var rightToLeft: Bool

    var spreadCount: Int { spread ? (pageCount + 1) / 2 : pageCount }
    /// Pages including the blank one that ends an odd-length book in a spread.
    var paddedPageCount: Int { spread ? spreadCount * 2 : pageCount }

    func spreadIndex(ofPage page: Int) -> Int { spread ? page / 2 : page }

    /// The pages of a spread in screen order, left to right. An index past the end is a blank page.
    func pages(inSpread index: Int) -> [Int] {
        guard spread else { return [index] }
        let first = index * 2
        return rightToLeft ? [first + 1, first] : [first, first + 1]
    }

    /// The book's binding: the right edge for a right-to-left single page.
    var bindingOnRight: Bool { rightToLeft }

    /// A single curling page bound on the right. UIKit's page curl only turns forward from right
    /// to left (whatever the spine location), so the page turner mirrors itself, and each page
    /// back, to turn the Japanese way: swipe left to right and the leaf lifts by its left edge.
    var mirrorsCurl: Bool { rightToLeft && !spread }

    /// Whether the screen showing `page` also shows the book's last page (in a spread, the last
    /// spread's first page is the current one).
    func showsLastPage(atPage page: Int) -> Bool {
        pageCount > 0 && spreadIndex(ofPage: page) == spreadIndex(ofPage: pageCount - 1)
    }

    /// How much of the book lies under each screen edge, 0...1, for the stacked page edges: pages
    /// already read pile up on the side you came from.
    func edgeFractions(atPage page: Int) -> (left: CGFloat, right: CGFloat) {
        let read = pageCount <= 1 ? 0 : CGFloat(min(max(page, 0), pageCount - 1)) / CGFloat(pageCount - 1)
        return rightToLeft ? (1 - read, read) : (read, 1 - read)
    }
}

/// Where the type goes on a page: the generous top (天) and bottom (地) margins of a bunko, and
/// room at the binding for the gutter and the ribbon.
enum PageGeometry {
    struct Margins {
        var top: CGFloat
        var bottom: CGFloat
        var binding: CGFloat
        var outer: CGFloat
    }

    static func margins(page: CGSize) -> Margins {
        Margins(top: max(64, page.height * 0.085), bottom: max(56, page.height * 0.075), binding: 34, outer: 28)
    }

    static func textSize(page: CGSize) -> CGSize {
        let m = margins(page: page)
        return CGSize(width: max(0, page.width - m.binding - m.outer), height: max(0, page.height - m.top - m.bottom))
    }

    static func textRect(page: CGSize, bindingOnRight: Bool) -> CGRect {
        let m = margins(page: page)
        let size = textSize(page: page)
        return CGRect(x: bindingOnRight ? m.outer : m.binding, y: m.top, width: size.width, height: size.height)
    }
}
