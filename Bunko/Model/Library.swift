import Foundation
import Observation
import UIKit

/// The books on this device: files in Application Support, plus a small index.
@MainActor @Observable
final class Library {
    enum Failure: LocalizedError {
        case unreadable(String)
        var errorDescription: String? {
            switch self { case .unreadable(let name): "Bunko can't read \(name). It opens EPUB and plain-text books." }
        }
    }

    private(set) var books: [Book] = []
    @ObservationIgnored let root: URL
    @ObservationIgnored private var coverCache: [String: UIImage] = [:]

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL), let saved = try? JSONDecoder().decode([Book].self, from: data) {
            books = saved
        }
    }

    private var booksFolder: URL { root.appendingPathComponent("Books", isDirectory: true) }
    private var indexURL: URL { root.appendingPathComponent("library.json") }

    func fileURL(for book: Book) -> URL { booksFolder.appendingPathComponent(book.fileName) }
    private func coverURL(for id: String) -> URL { booksFolder.appendingPathComponent("\(id).cover") }

    /// The book's own cover art (EPUB only), under the paper.
    func originalCover(for book: Book) -> UIImage? {
        if let image = coverCache[book.id] { return image }
        guard let image = UIImage(contentsOfFile: coverURL(for: book.id).path) else { return nil }
        coverCache[book.id] = image
        return image
    }

    @discardableResult
    func importFile(at url: URL) throws -> Book {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try add(data: Data(contentsOf: url), fileName: url.lastPathComponent)
    }

    /// Adds (or replaces) a book from its file's bytes.
    @discardableResult
    func add(data: Data, fileName: String, shopID: UUID? = nil, rightToLeft: Bool? = nil) throws -> Book {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let stem = (fileName as NSString).deletingPathExtension
        let book: Book
        var cover: Data? = nil
        if ext == "epub" || (ext != "txt" && data.starts(with: [0x50, 0x4B])) {
            guard let epub = try? EPUB(data: data) else { throw Failure.unreadable(fileName) }
            let title = epub.title.isEmpty ? stem : epub.title
            let japanese = epub.language.lowercased().hasPrefix("ja")
            let id = Book.stableID(title: title, author: epub.author)
            book = Book(id: id, title: title, author: epub.author, fileName: "\(id).epub", format: .epub,
                        language: epub.language, rightToLeft: rightToLeft ?? (epub.rightToLeft || japanese),
                        addedAt: .now, shopID: shopID, series: epub.series, seriesIndex: epub.seriesIndex)
            cover = epub.coverImageData()
        } else if let text = PlainText.decode(data) {
            let japanese = Script.looksJapanese(text)
            let id = Book.stableID(title: stem, author: "")
            book = Book(id: id, title: stem, author: "", fileName: "\(id).txt", format: .txt,
                        language: japanese ? "ja" : "", rightToLeft: rightToLeft ?? japanese,
                        addedAt: .now, shopID: shopID)
        } else {
            throw Failure.unreadable(fileName)
        }
        try data.write(to: fileURL(for: book), options: .atomic)
        if let cover { try? cover.write(to: coverURL(for: book.id), options: .atomic) }
        coverCache[book.id] = nil
        books.removeAll { $0.id == book.id }
        books.insert(book, at: 0)
        save()
        return book
    }

    func remove(_ book: Book) {
        try? FileManager.default.removeItem(at: fileURL(for: book))
        try? FileManager.default.removeItem(at: coverURL(for: book.id))
        books.removeAll { $0.id == book.id }
        save()
    }

    nonisolated static func content(of book: Book, at url: URL) throws -> BookContent {
        let data = try Data(contentsOf: url)
        switch book.format {
        case .epub: return try EPUB(data: data).content()
        case .txt: return PlainText.content(PlainText.decode(data) ?? "")
        }
    }

    /// Two public-domain books on a new shelf: 吾輩は猫である (vertical, in Basil's own paper
    /// cover) and Alice's Adventures in Wonderland.
    func addSamplesIfNeeded(sync: SyncStore) {
        let flag = "bunko.samples"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        let samples: [(file: String, title: String, author: String, rtl: Bool, paper: CoverStyle.Paper)] = [
            ("alice", "Alice's Adventures in Wonderland", "Lewis Carroll", false, .washi),
            ("wagahai", "吾輩は猫である", "夏目漱石", true, .basil),
        ]
        for sample in samples {
            guard let url = Bundle.main.url(forResource: sample.file, withExtension: "txt"),
                  let data = try? Data(contentsOf: url) else { continue }
            let id = Book.stableID(title: sample.title, author: sample.author)
            let book = Book(id: id, title: sample.title, author: sample.author, fileName: "\(id).txt", format: .txt,
                            language: sample.rtl ? "ja" : "en", rightToLeft: sample.rtl, addedAt: .now, shopID: nil)
            guard (try? data.write(to: fileURL(for: book), options: .atomic)) != nil else { continue }
            books.removeAll { $0.id == id }
            books.insert(book, at: 0)
            if sync.storedCover(for: book) == nil { sync.setCover(CoverStyle(paper: sample.paper), for: book) }
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
