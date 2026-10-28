import CoreText
import Observation
import UIKit

/// An open book: its pages for the current screen and settings, where you are, the ribbon, and
/// whether the book is open or shut.
@MainActor @Observable
final class ReaderModel {
    struct Jump: Equatable {
        let page: Int
        let id = UUID()
    }

    let book: Book
    private(set) var typeset: TypesetBook?
    private(set) var pages: [NSRange] = []
    /// Changes whenever the pages are cut again (new size, font, paper), so the page turner reloads.
    private(set) var pagesVersion = 0
    private(set) var layout = SpreadLayout(pageCount: 0, spread: false, rightToLeft: false)
    private(set) var vertical = false
    private(set) var settings = ReaderSettings()
    private(set) var loadError: String?

    private(set) var currentPage = 0
    private(set) var ribbonOffset = 0
    /// Position plus reading history (started, finished, pages today); what the obi and the wear show.
    private(set) var progress: ReadingProgress
    var jump: Jump?
    var isClosed: Bool
    var showsSettings = false
    /// 1 while open; less while two fingers pinch the book shut.
    var squeeze: CGFloat = 1

    @ObservationIgnored private var content: BookContent?
    @ObservationIgnored private var setters: [Int: CTFramesetter] = [:]
    @ObservationIgnored private var anchorOffset = 0
    @ObservationIgnored private let library: Library
    @ObservationIgnored private let sync: SyncStore

    init(book: Book, library: Library, sync: SyncStore, startClosed: Bool = false) {
        self.book = book
        self.library = library
        self.sync = sync
        isClosed = startClosed
        let saved = sync.progress(for: book)
        progress = saved ?? ReadingProgress(offset: 0, ribbon: 0, fraction: 0)
        anchorOffset = progress.offset
        ribbonOffset = progress.ribbon
    }

    var currentOffset: Int { pages.indices.contains(currentPage) ? pages[currentPage].location : anchorOffset }
    var ribbonPage: Int { Paginator.page(containing: ribbonOffset, in: pages) }
    var fraction: Double { layout.pageCount <= 1 ? 0 : Double(currentPage) / Double(layout.pageCount - 1) }

    /// Cuts the book into pages for this screen and these settings. Called again on any change;
    /// the reading position is kept by character, not by page.
    func layout(size: CGSize, settings: ReaderSettings) async {
        guard size.width > 50, size.height > 50 else { return }
        // Settings sliders change many times a second: only the last value gets typeset.
        try? await Task.sleep(for: .milliseconds(pages.isEmpty ? 0 : 120))
        if Task.isCancelled { return }
        if content == nil {
            let book = book, url = library.fileURL(for: book)
            do {
                content = try await Task.detached(priority: .userInitiated) { try Library.content(of: book, at: url) }.value
            } catch {
                loadError = "This book couldn't be opened."
                return
            }
        }
        guard let content else { return }
        let vertical = settings.isVertical(for: book)
        let typeface = settings.face(for: book)
        let spread = settings.usesSpread(in: size)
        let pageSize = CGSize(width: spread ? size.width / 2 : size.width, height: size.height)
        let textSize = PageGeometry.textSize(page: pageSize)
        let anchor = currentOffset
        let result = await Task.detached(priority: .userInitiated) {
            let typeset = Typesetter.typeset(content, settings: settings, typeface: typeface, vertical: vertical)
            return (typeset, Paginator.pages(typeset, size: textSize, vertical: vertical))
        }.value
        if Task.isCancelled { return }

        typeset = result.0
        pages = result.1
        setters = [:]
        self.vertical = vertical
        self.settings = settings
        layout = SpreadLayout(pageCount: pages.count, spread: spread, rightToLeft: vertical)
        currentPage = Paginator.page(containing: anchor, in: pages)
        pagesVersion += 1
    }

    func render(page: Int, side: PageRender.Side) -> PageRender {
        let edges = layout.edgeFractions(atPage: currentPage)
        let edgeFraction: CGFloat = switch side {
        case .left: edges.left
        case .right: edges.right
        case .single: layout.bindingOnRight ? edges.left : edges.right
        }
        var render = PageRender(setter: nil, range: CFRange(location: 0, length: 0), vertical: vertical,
                                paper: settings.paper, side: side, bindingOnRight: layout.bindingOnRight,
                                edgeFraction: edgeFraction, showsEdges: settings.showsPageEdges)
        guard pages.indices.contains(page), let typeset else { return render }
        let range = pages[page]
        let chapter = typeset.chapter(at: range.location)
        render.setter = framesetter(chapter: chapter, in: typeset)
        render.range = CFRange(location: range.location - typeset.chapterStarts[chapter], length: range.length)
        render.number = page + 1
        if settings.showsHeader {
            // Book title on the left-hand page, chapter on the right, as in a printed bunko.
            let chapterTitle = typeset.chapterTitles[chapter]
            render.header = side == .right && !chapterTitle.isEmpty ? chapterTitle : book.title
        }
        return render
    }

    private func framesetter(chapter: Int, in typeset: TypesetBook) -> CTFramesetter {
        if let setter = setters[chapter] { return setter }
        let start = typeset.chapterStarts[chapter]
        let end = chapter + 1 < typeset.chapterStarts.count ? typeset.chapterStarts[chapter + 1] : typeset.text.length
        let setter = CTFramesetterCreateWithAttributedString(typeset.text.attributedSubstring(from: NSRange(location: start, length: end - start)))
        setters[chapter] = setter
        return setter
    }

    /// The page turner settled on a page (a swipe, not a jump).
    func turned(to page: Int) {
        guard page != currentPage, pages.indices.contains(page) else { return }
        // Pages read forward one turn at a time count toward today and the cover's wear.
        let forward = page - currentPage
        if forward > 0 && forward <= 4 { progress.recordTurn(pages: forward) }
        currentPage = page
        if settings.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55) }
        save()
    }

    func go(to page: Int) {
        guard pages.indices.contains(page) else { return }
        currentPage = page
        jump = Jump(page: page)
        save()
    }

    func go(toOffset offset: Int) { go(to: Paginator.page(containing: offset, in: pages)) }

    /// A tug on the ribbon: back to where it lies.
    func followRibbon() {
        if settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        go(to: ribbonPage)
    }

    /// Holding the ribbon lays it in the current page.
    func moveRibbonHere() {
        ribbonOffset = currentOffset
        if settings.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        save()
    }

    /// Shutting the book lays the ribbon where you stopped.
    func close() {
        ribbonOffset = currentOffset
        squeeze = 1
        isClosed = true
        save()
    }

    func open() {
        isClosed = false
        if pages.indices.contains(ribbonPage), ribbonPage != currentPage { go(to: ribbonPage) }
    }

    private func save() {
        guard !pages.isEmpty else { return }
        progress.offset = currentOffset
        progress.ribbon = ribbonOffset
        progress.fraction = fraction
        if currentPage >= pages.count - 1, progress.finishedAt == nil, progress.pagesRead > 0 { progress.finishedAt = .now }
        sync.setProgress(progress, for: book)
    }
}
