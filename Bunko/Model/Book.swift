import CryptoKit
import Foundation

/// A book on the shelf. The file itself lives in the library folder; everything here is small.
struct Book: Codable, Identifiable, Hashable {
    enum Format: String, Codable { case epub, txt }

    /// Same on every device for the same title and author, so reading position and covers sync
    /// even when each device downloaded its own copy.
    var id: String
    var title: String
    var author: String
    var fileName: String
    var format: Format
    var language: String
    /// Read right to left (vertical Japanese, or an EPUB that says so).
    var rightToLeft: Bool
    var addedAt: Date
    var shopID: UUID?

    static func stableID(title: String, author: String) -> String {
        let key = (title + "\u{1F}" + author).precomposedStringWithCanonicalMapping.lowercased()
        return SHA256.hash(data: Data(key.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

/// A book's text, chapter by chapter, with the markup gone.
struct BookContent: Equatable, Sendable {
    struct Chapter: Equatable, Sendable {
        var title: String
        var paragraphs: [String]
    }
    var chapters: [Chapter]
}

/// Where you are in a book, by character offset so it survives a change of font or screen.
struct ReadingProgress: Codable, Equatable {
    var offset: Int
    /// Where the ribbon (スピン) lies: set when the book is closed or by holding the ribbon.
    var ribbon: Int
    var fraction: Double
}

enum Script {
    /// True when kana and kanji make up a good share of the letters at the start of the text.
    static func looksJapanese(_ text: String) -> Bool {
        var cjk = 0, letters = 0
        for scalar in text.unicodeScalars.prefix(3000) {
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xFF66...0xFF9D:
                cjk += 1; letters += 1
            default:
                if CharacterSet.letters.contains(scalar) { letters += 1 }
            }
        }
        return letters > 0 && Double(cjk) / Double(letters) > 0.3
    }
}
