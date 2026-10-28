import Foundation

/// What you can correct about a book: the details its file gave it, or that you fixed. Edits are
/// kept by Bunko (and sync through iCloud), never written into the file, and the book keeps its
/// ID so its place, ribbon and cover stay with it.
struct BookInfo: Codable, Equatable {
    var title: String
    var author: String
    var language: String
    /// Bound on the right and read right to left.
    var rightToLeft: Bool
    var series: String?
    var seriesIndex: Double?

    init(_ book: Book) {
        title = book.title
        author = book.author
        language = book.language
        rightToLeft = book.rightToLeft
        series = book.series
        seriesIndex = book.seriesIndex
    }

    /// Blank fields fall back to the book's own; a blank series means none.
    func cleaned(fallback book: Book) -> BookInfo {
        var info = self
        info.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if info.title.isEmpty { info.title = book.title }
        info.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        info.language = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = series?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        info.series = name.isEmpty ? nil : name
        if info.series == nil { info.seriesIndex = nil }
        return info
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        author = (try? c.decodeIfPresent(String.self, forKey: .author)) ?? ""
        language = (try? c.decodeIfPresent(String.self, forKey: .language)) ?? ""
        rightToLeft = (try? c.decodeIfPresent(Bool.self, forKey: .rightToLeft)) ?? false
        series = try? c.decodeIfPresent(String.self, forKey: .series)
        seriesIndex = try? c.decodeIfPresent(Double.self, forKey: .seriesIndex)
    }
}

extension Book {
    func applying(_ info: BookInfo) -> Book {
        var book = self
        book.title = info.title.isEmpty ? title : info.title
        book.author = info.author
        book.language = info.language
        book.rightToLeft = info.rightToLeft
        book.series = info.series
        book.seriesIndex = info.series == nil ? nil : info.seriesIndex
        return book
    }
}

extension SyncStore {
    /// Your corrections to a book's details, if any.
    func info(for book: Book) -> BookInfo? {
        value(BookInfo.self, "info.\(book.id)")
    }

    func setInfo(_ info: BookInfo, for book: Book) {
        set(info, "info.\(book.id)")
    }
}

extension Library {
    /// Saves your corrections and shows them on the shelf, here and (through iCloud) elsewhere.
    func edit(_ book: Book, to info: BookInfo, sync: SyncStore) {
        let info = info.cleaned(fallback: book)
        sync.setInfo(info, for: book)
        update(book.applying(info))
    }

    /// Takes corrections made on another device (or before this copy was downloaded).
    func applyEdits(from sync: SyncStore) {
        for book in books {
            guard let info = sync.info(for: book) else { continue }
            let edited = book.applying(info)
            if edited != book { update(edited) }
        }
    }

    /// The details as the book's own file gives them, to undo your corrections.
    func originalInfo(for book: Book) -> BookInfo? {
        guard let data = try? Data(contentsOf: fileURL(for: book)) else { return nil }
        var info = BookInfo(book)
        switch book.format {
        case .epub:
            guard let epub = try? EPUB(data: data) else { return nil }
            if !epub.title.isEmpty { info.title = epub.title }
            info.author = epub.author
            info.language = epub.language
            info.rightToLeft = epub.declaresDirection ? epub.rightToLeft : Book.boundOnRight(language: epub.language)
            info.series = epub.series
            info.seriesIndex = epub.seriesIndex
        case .txt:
            let language = Script.language(of: PlainText.decode(data) ?? "")
            info.language = language
            info.rightToLeft = Book.boundOnRight(language: language)
            info.series = nil
            info.seriesIndex = nil
        }
        return info
    }
}
