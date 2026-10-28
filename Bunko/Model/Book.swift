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
    /// The series it belongs to and its place in it, from the book's own metadata.
    var series: String?
    var seriesIndex: Double?

    /// A volume of a series: its name and number.
    struct Volume: Equatable {
        var series: String
        var index: Double?

        /// 3, or 2.5 for an in-between volume.
        static func label(_ index: Double) -> String {
            index.rounded() == index ? String(Int(index)) : String(format: "%g", index)
        }

        /// 三, 十二, 二十三 for a vertical title; an in-between or very high volume stays in figures.
        static func kanji(_ index: Double) -> String {
            let n = Int(index)
            guard index.rounded() == index, (1...99).contains(n) else { return label(index) }
            let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
            let tens = n / 10, ones = n % 10
            return (tens == 0 ? "" : (tens == 1 ? "" : digits[tens]) + "十") + digits[ones]
        }
    }

    /// Its series, from its metadata or else its title (Vol. 3, 第3巻, (3)), so books that came
    /// without the metadata still find their set.
    var volume: Volume? {
        if let series, !series.trimmingCharacters(in: .whitespaces).isEmpty {
            return Volume(series: series.trimmingCharacters(in: .whitespaces), index: seriesIndex)
        }
        return Self.volume(fromTitle: title)
    }

    /// What picks its automatic design: the series if it's in one, so the set looks alike.
    var designKey: String {
        volume.map { "series:" + $0.series.lowercased() } ?? id
    }

    /// A series and number read off a title: "Name, Vol. 3", "Name Book 2", "Name #4", "Name (3)",
    /// "名前 第3巻", "名前 3巻", "名前 第三巻", "名前（３）", and for a Japanese title "名前 3".
    static func volume(fromTitle title: String) -> Volume? {
        let text = title.trimmingCharacters(in: .whitespaces)
        let patterns = [
            #"^(.+?)[\s,:;.\-–—]+(?:vol\.?|volume|book|part|no\.|#)\s*(\d+(?:\.\d+)?)\b.*$"#,
            #"^(.+?)\s*第\s*([0-9０-９〇一二三四五六七八九十百]+)\s*[巻部集]\s*.*$"#,
            #"^(.+?)\s+([0-9０-９]+)\s*巻\s*.*$"#,
            #"^(.+?)\s*[（(]\s*([0-9０-９]{1,3})\s*[)）]\s*$"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let name = Range(match.range(at: 1), in: text), let number = Range(match.range(at: 2), in: text),
                  let index = numeral(String(text[number]))
            else { continue }
            let series = text[name].trimmingCharacters(in: CharacterSet(charactersIn: " ,:;.-–—　"))
            if !series.isEmpty { return Volume(series: series, index: index) }
        }
        // A bare trailing number only for a Japanese title (ワンピース 3); "Fahrenheit 451" isn't a series.
        if Script.looksJapanese(text),
           let regex = try? NSRegularExpression(pattern: #"^(.+?)[\s　]+([0-9０-９]{1,3})$"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let name = Range(match.range(at: 1), in: text), let number = Range(match.range(at: 2), in: text),
           let index = numeral(String(text[number])) {
            return Volume(series: String(text[name]), index: index)
        }
        return nil
    }

    /// 3, ３, 三, 十二, 二十 as a number.
    static func numeral(_ text: String) -> Double? {
        let ascii = String(text.map { ch -> Character in
            guard let v = ch.unicodeScalars.first?.value, (0xFF10...0xFF19).contains(v) else { return ch }
            return Character(UnicodeScalar(v - 0xFF10 + 0x30)!)
        })
        if let value = Double(ascii) { return value }
        let digits: [Character: Int] = ["〇": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        var total = 0, current = 0
        for ch in ascii {
            if let d = digits[ch] { current = d }
            else if ch == "十" { total += max(current, 1) * 10; current = 0 }
            else if ch == "百" { total += max(current, 1) * 100; current = 0 }
            else { return nil }
        }
        let value = total + current
        return value > 0 ? Double(value) : nil
    }

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
    /// Where the ribbon (スピン) lies, when it's in: laid by tapping the gutter or holding the ribbon.
    var ribbon: Int
    /// The ribbon isn't in the book until you lay it in.
    var hasRibbon = false
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
        hasRibbon = (try? c.decodeIfPresent(Bool.self, forKey: .hasRibbon)) ?? false
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
