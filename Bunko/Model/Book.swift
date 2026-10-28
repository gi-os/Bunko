import CryptoKit
import Foundation
import NaturalLanguage

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
    /// Bound on the right and read right to left: vertical Japanese, a right-to-left script
    /// (Arabic, Hebrew…), or an EPUB that says so.
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

/// Where you are in a book, by character offset so it survives a change of font or screen, and
/// what reading it has been like: when you started and finished, and how much you've read (the
/// cover wears in, the obi shows today's pages).
struct ReadingProgress: Codable, Equatable {
    var offset: Int
    /// Where the ribbon (スピン) lies: set when the book is closed or by holding the ribbon.
    var ribbon: Int
    var fraction: Double
    var startedAt: Date?
    var finishedAt: Date?
    /// Pages turned forward, ever.
    var pagesRead = 0
    /// The day `pagesOnDay` counts (yyyy-M-d, local).
    var day = ""
    var pagesOnDay = 0

    init(offset: Int, ribbon: Int, fraction: Double) {
        self.offset = offset
        self.ribbon = ribbon
        self.fraction = fraction
    }

    /// 0 for a new book, 1 for a well-loved one.
    var wear: Double { min(1, Double(pagesRead) / 600) }

    func pagesToday(now: Date = .now, calendar: Calendar = .current) -> Int {
        day == Self.dayKey(now, calendar: calendar) ? pagesOnDay : 0
    }

    mutating func recordTurn(pages: Int, now: Date = .now, calendar: Calendar = .current) {
        guard pages > 0 else { return }
        if startedAt == nil { startedAt = now }
        let today = Self.dayKey(now, calendar: calendar)
        if day != today { day = today; pagesOnDay = 0 }
        pagesOnDay += pages
        pagesRead += pages
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let d = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        offset = (try? c.decodeIfPresent(Int.self, forKey: .offset)) ?? 0
        ribbon = (try? c.decodeIfPresent(Int.self, forKey: .ribbon)) ?? offset
        fraction = (try? c.decodeIfPresent(Double.self, forKey: .fraction)) ?? 0
        startedAt = try? c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try? c.decodeIfPresent(Date.self, forKey: .finishedAt)
        pagesRead = (try? c.decodeIfPresent(Int.self, forKey: .pagesRead)) ?? 0
        day = (try? c.decodeIfPresent(String.self, forKey: .day)) ?? ""
        pagesOnDay = (try? c.decodeIfPresent(Int.self, forKey: .pagesOnDay)) ?? 0
    }
}

extension Book {
    /// A book goes the way its language does: Japanese is set in columns and bound on the right;
    /// Arabic, Hebrew, Persian and Urdu run in rows from the right, also bound on the right; the
    /// rest (English first) run left to right, bound on the left.
    static func boundOnRight(language: String) -> Bool {
        languageCode(language) == "ja" || writtenRightToLeft(language)
    }

    /// Rows that run right to left.
    static func writtenRightToLeft(_ language: String) -> Bool {
        ["ar", "he", "iw", "fa", "ur", "yi", "ps", "sd", "ug", "dv", "ckb"].contains(languageCode(language))
    }

    static func languageCode(_ language: String) -> String {
        language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
    }

    var rowsRightToLeft: Bool { Self.writtenRightToLeft(language) }
}

enum Script {
    /// The text's language (BCP 47), from its opening: "ja" for kana and kanji, otherwise what
    /// the system recognises, or "" when it can't tell.
    static func language(of text: String) -> String {
        if looksJapanese(text) { return "ja" }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(3000)))
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return "" }
        return language.rawValue
    }

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
