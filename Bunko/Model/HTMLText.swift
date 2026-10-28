import Foundation

/// Plain paragraphs from a chapter's XHTML. Forgiving on purpose (EPUBs are full of entities an
/// XML parser rejects): block tags break paragraphs, furigana readings (<rt>) and scripts drop out,
/// and the first heading becomes the chapter title.
enum HTMLText {
    struct Result: Equatable {
        var title: String?
        var paragraphs: [String]
    }

    private static let blocks: Set<String> = [
        "p", "div", "br", "li", "blockquote", "section", "article", "tr", "hr", "dt", "dd",
        "figcaption", "pre", "h1", "h2", "h3", "h4", "h5", "h6",
    ]
    private static let skipped: Set<String> = ["rt", "rp", "script", "style", "head", "title"]
    private static let entities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "middot": "·", "copy": "©", "shy": "",
    ]

    static func extract(_ html: String) -> Result {
        var paragraphs: [String] = []
        var title: String?
        var current = ""
        var skipDepth = 0
        var inHeading = false

        func flush() {
            let text = collapse(current)
            current = ""
            guard !text.isEmpty else { return }
            if inHeading && title == nil { title = text } else { paragraphs.append(text) }
        }

        var i = html.startIndex
        while i < html.endIndex {
            let c = html[i]
            if c == "<" {
                if html[i...].hasPrefix("<!--") {
                    if let end = html.range(of: "-->", range: i..<html.endIndex) { i = end.upperBound; continue }
                    break
                }
                guard let close = html[i...].firstIndex(of: ">") else { break }
                let tag = html[html.index(after: i)..<close]
                i = html.index(after: close)
                if tag.hasPrefix("!") || tag.hasPrefix("?") { continue }
                let closing = tag.hasPrefix("/")
                let name = tag.drop(while: { $0 == "/" }).prefix(while: { $0.isLetter || $0.isNumber }).lowercased()
                let selfClosing = tag.hasSuffix("/")
                if skipped.contains(name) {
                    if closing { skipDepth = max(0, skipDepth - 1) } else if !selfClosing { skipDepth += 1 }
                    continue
                }
                if blocks.contains(name) {
                    flush()
                    if ["h1", "h2", "h3"].contains(name) { inHeading = !closing && !selfClosing }
                }
            } else if c == "&", let semi = html[i...].prefix(12).firstIndex(of: ";") {
                let name = String(html[html.index(after: i)..<semi])
                if skipDepth == 0 { current += decode(entity: name) ?? "&\(name);" }
                i = html.index(after: semi)
            } else {
                if skipDepth == 0 { current.append(c) }
                i = html.index(after: i)
            }
        }
        flush()
        return Result(title: title, paragraphs: paragraphs)
    }

    static func decode(entity name: String) -> String? {
        if name.hasPrefix("#") {
            let digits = name.dropFirst()
            let value = digits.first == "x" || digits.first == "X"
                ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
        return entities[name]
    }

    /// Whitespace runs become one space, except a line break between two Japanese characters,
    /// which was only ever a break in the source file.
    static func collapse(_ text: String) -> String {
        var out = ""
        var pendingSpace = false
        var pendingNewline = false
        for ch in text {
            if ch.isWhitespace {
                pendingSpace = true
                if ch.isNewline { pendingNewline = true }
                continue
            }
            if pendingSpace, let last = out.last {
                if !(pendingNewline && isWide(last) && isWide(ch)) { out.append(" ") }
            }
            pendingSpace = false
            pendingNewline = false
            out.append(ch)
        }
        return out
    }

    private static func isWide(_ c: Character) -> Bool {
        (c.unicodeScalars.first?.value ?? 0) >= 0x2E80
    }
}

/// Plain-text books, including Aozora Bunko files (ruby in 《》, notes in ［＃］).
enum PlainText {
    static func decode(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? String(data: data, encoding: .utf16)
    }

    static func content(_ text: String, title: String = "") -> BookContent {
        let cleaned = text
            .replacingOccurrences(of: "《[^》]*》", with: "", options: .regularExpression)
            .replacingOccurrences(of: "［＃[^］]*］", with: "", options: .regularExpression)
            .replacingOccurrences(of: "｜", with: "")
        let paragraphs = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return BookContent(chapters: [.init(title: title, paragraphs: paragraphs)])
    }
}
