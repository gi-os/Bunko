import CoreText
import SwiftUI
import UIKit

/// The whole book as one attributed string, with where each chapter starts.
struct TypesetBook: @unchecked Sendable {
    var text: NSAttributedString
    var chapterStarts: [Int]
    var chapterTitles: [String]

    func chapter(at offset: Int) -> Int {
        var index = 0
        for (i, start) in chapterStarts.enumerated() where start <= offset { index = i }
        return index
    }
}

enum Typesetter {
    /// The bundled faces (Resources/Fonts, listed in project.yml UIAppFonts), falling back to the
    /// system's Hiragino. Bold: Shippori's own bold, Literata's variable weight axis.
    static func font(_ typeface: ReaderSettings.Typeface, size: CGFloat, bold: Bool = false) -> UIFont {
        let (name, fallback) = switch typeface {
        case .mincho: (bold ? "ShipporiMincho-Bold" : "ShipporiMincho-Regular", bold ? "HiraMinProN-W6" : "HiraMinProN-W3")
        case .oldMincho: ("ZenOldMincho-Regular", bold ? "HiraMinProN-W6" : "HiraMinProN-W3")
        case .gothic: ("ZenKakuGothicNew-Regular", bold ? "HiraginoSans-W6" : "HiraginoSans-W3")
        case .serif: ("Literata-Regular", bold ? "Georgia-Bold" : "Georgia")
        }
        guard let font = UIFont(name: name, size: size) else {
            return UIFont(name: fallback, size: size) ?? .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        }
        guard bold, typeface == .serif else { return font }
        let weightAxis = 0x7767_6874 // 'wght'
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        return UIFont(descriptor: font.fontDescriptor.addingAttributes([variation: [weightAxis: 640]]), size: size)
    }

    static func swiftUIFont(_ typeface: ReaderSettings.Typeface, size: CGFloat, bold: Bool = false) -> Font {
        Font(font(typeface, size: size, bold: bold) as CTFont)
    }

    /// `language` (BCP 47) picks the hyphenation dictionary for horizontal text; a right-to-left
    /// one (Arabic, Hebrew…) sets its rows from the right.
    static func typeset(_ content: BookContent, settings: ReaderSettings, typeface: ReaderSettings.Typeface,
                        vertical: Bool, language: String = "") -> TypesetBook {
        let size = CGFloat(settings.fontSize)
        let ink = settings.paper.ink
        let rowsRightToLeft = !vertical && Book.writtenRightToLeft(language)
        let body = NSMutableParagraphStyle()
        // Vertical Japanese wants wide 行間; Western rows read better closer.
        body.lineSpacing = size * CGFloat(settings.lineSpacing) * (vertical ? 1 : 0.5)
        body.firstLineHeadIndent = size
        body.alignment = .justified
        body.hyphenationFactor = vertical ? 0 : 0.8
        if rowsRightToLeft { body.baseWritingDirection = .rightToLeft }
        let heading = NSMutableParagraphStyle()
        heading.lineSpacing = body.lineSpacing
        heading.paragraphSpacing = size * 2
        heading.paragraphSpacingBefore = size * 2
        heading.firstLineHeadIndent = vertical ? size * 2 : 0
        heading.alignment = vertical ? .natural : .center
        if rowsRightToLeft { heading.baseWritingDirection = .rightToLeft }

        func attributes(_ font: UIFont, _ style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink.cgColor,
                .paragraphStyle: style,
            ]
            if vertical { attrs[NSAttributedString.Key(kCTVerticalFormsAttributeName as String)] = true }
            if !language.isEmpty { attrs[NSAttributedString.Key(kCTLanguageAttributeName as String)] = language }
            return attrs
        }
        let bodyAttrs = attributes(font(typeface, size: size), body)
        let headingAttrs = attributes(font(typeface, size: size * 1.3, bold: true), heading)

        let text = NSMutableAttributedString()
        var starts: [Int] = []
        var titles: [String] = []
        for (index, chapter) in content.chapters.enumerated() {
            starts.append(text.length)
            titles.append(chapter.title.isEmpty ? (content.chapters.count > 1 ? "\(index + 1)" : "") : chapter.title)
            if !chapter.title.isEmpty {
                text.append(NSAttributedString(string: chapter.title + "\n", attributes: headingAttrs))
            }
            for paragraph in chapter.paragraphs {
                let set = vertical ? paragraph : SmartQuotes.curl(paragraph)
                text.append(NSAttributedString(string: set + "\n", attributes: bodyAttrs))
            }
        }
        return TypesetBook(text: text, chapterStarts: starts, chapterTitles: titles)
    }
}

/// Splits a typeset book into pages that fit a text block. Each chapter starts on a new page.
enum Paginator {
    static func frameAttributes(vertical: Bool) -> CFDictionary? {
        vertical ? [kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue] as CFDictionary : nil
    }

    static func pages(_ book: TypesetBook, size: CGSize, vertical: Bool) -> [NSRange] {
        guard size.width > 20, size.height > 20, book.text.length > 0 else { return [] }
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let attrs = frameAttributes(vertical: vertical)
        var pages: [NSRange] = []
        let ends = Array(book.chapterStarts.dropFirst()) + [book.text.length]
        for (start, end) in zip(book.chapterStarts, ends) where end > start {
            let chapter = book.text.attributedSubstring(from: NSRange(location: start, length: end - start))
            let setter = CTFramesetterCreateWithAttributedString(chapter)
            var location = 0
            while location < chapter.length {
                // A page always takes at least one character, so a huge glyph can't stall the book.
                let visible: Int
                if vertical {
                    let frame = CTFramesetterCreateFrame(setter, CFRange(location: location, length: 0), path, attrs)
                    visible = max(1, CTFrameGetVisibleStringRange(frame).length)
                } else {
                    visible = LineSetter.lay(chapter, typesetter: CTFramesetterGetTypesetter(setter), from: location, size: size).next - location
                }
                pages.append(NSRange(location: start + location, length: min(visible, chapter.length - location)))
                location += visible
            }
        }
        return pages
    }

    /// The page holding a character offset.
    static func page(containing offset: Int, in pages: [NSRange]) -> Int {
        guard !pages.isEmpty else { return 0 }
        var low = 0, high = pages.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if pages[mid].location <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }
}

/// Typewriter quotes made typographic for horizontal (Western) text: “ ” ‘ ’, an apostrophe
/// inside a word. One character for one, so reading positions don't move.
enum SmartQuotes {
    static func curl(_ text: String) -> String {
        guard text.contains("\"") || text.contains("'") else { return text }
        var out = ""
        out.reserveCapacity(text.utf16.count)
        var previous: Character?
        for character in text {
            switch character {
            case "\"": out.append(opens(after: previous) ? "\u{201C}" : "\u{201D}")
            case "'": out.append(opens(after: previous) ? "\u{2018}" : "\u{2019}")
            default: out.append(character)
            }
            previous = character
        }
        return out
    }

    private static func opens(after previous: Character?) -> Bool {
        guard let previous else { return true }
        return previous.isWhitespace || "([{\u{2014}\u{2013}-/\u{201C}\u{2018}".contains(previous)
    }
}
