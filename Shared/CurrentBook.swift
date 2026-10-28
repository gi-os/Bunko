import Foundation

/// The book in your hands, as the widget sees it. The app writes it to the shared App Group
/// container whenever a book is opened or shut, with the cover drawn as it looks right now (paper,
/// wear), so the widget never has to know how to draw one.
struct CurrentBook: Codable, Equatable {
    var id: String
    var title: String
    var author: String
    var rightToLeft: Bool
    /// The ribbon's colour, hex.
    var ribbonColor: String

    static let appGroup = "group.com.gios.bunko"

    static func folder(_ fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static func load(from folder: URL? = folder()) -> (book: CurrentBook, cover: Data?)? {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent(infoFile)),
              let book = try? JSONDecoder().decode(CurrentBook.self, from: data) else { return nil }
        return (book, try? Data(contentsOf: folder.appendingPathComponent(coverFile)))
    }

    func save(cover png: Data?, to folder: URL? = CurrentBook.folder()) {
        guard let folder, let data = try? JSONEncoder().encode(self) else { return }
        if let png { try? png.write(to: folder.appendingPathComponent(Self.coverFile), options: .atomic) }
        try? data.write(to: folder.appendingPathComponent(Self.infoFile), options: .atomic)
    }

    private static let infoFile = "current-book.json"
    private static let coverFile = "current-cover.png"
}

/// bunko://book/<id> opens that book on its cover: what tapping the widget does.
enum BunkoLink {
    static let scheme = "bunko"

    static func url(book id: String) -> URL {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "book"
        parts.path = "/" + id
        return parts.url ?? URL(string: "\(scheme)://")!
    }

    static func bookID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "book" else { return nil }
        let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return id.isEmpty ? nil : id
    }
}
