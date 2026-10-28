import SwiftUI
import WidgetKit

/// Draws the current book's cover as it looks now (paper, wear, the obi once finished) for the
/// widget, writes it to the App Group, and asks WidgetKit to reload, only when something changed:
/// reloads asked for from the background come out of a daily budget.
@MainActor
enum WidgetSnapshot {
    /// Points; drawn at 3x, about what a small widget shows.
    static let size = CGSize(width: 140, height: 140 * 148 / 105)

    static func update(library: Library, sync: SyncStore) {
        guard let id = Opener.currentBookID, let book = library.books.first(where: { $0.id == id }),
              let folder = CurrentBook.folder() else { return }
        let current = CurrentBook(id: book.id, title: book.title, author: book.author,
                                  rightToLeft: book.rightToLeft, ribbonColor: sync.settings.ribbonColor)
        let png = cover(for: book, library: library, sync: sync)?.pngData()
        if let saved = CurrentBook.load(from: folder), saved.book == current, saved.cover == png { return }
        current.save(cover: png, to: folder)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func cover(for book: Book, library: Library, sync: SyncStore) -> UIImage? {
        let progress = sync.progress(for: book)
        let japanese = book.printsJapanese
        let renderer = ImageRenderer(content:
            CoverView(style: sync.cover(for: book), book: book, original: library.originalCover(for: book),
                      wear: progress?.wear ?? 0, obi: Obi.finished(progress, japanese: japanese))
                .frame(width: size.width, height: size.height))
        renderer.scale = 3
        return renderer.uiImage
    }
}
