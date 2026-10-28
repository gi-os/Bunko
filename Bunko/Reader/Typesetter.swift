import CoreText
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
    static func font(_ typeface: ReaderSettings.Typeface, size: CGFloat) -> UIFont {
        let name = switch typeface {
        case .mincho: "HiraMinProN-W3"
        case .gothic: "HiraginoSans-W3"
        case .serif: "IowanOldStyle-Roman"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    static func typeset(_ content: BookContent, settings: ReaderSettings, vertical: Bool) -> TypesetBook {
        let size = CGFloat(settings.fontSize)
        let ink = settings.paper.ink
        let body = NSMutableParagraphStyle()
        body.lineSpacing = size * CGFloat(settings.lineSpacing)
        body.firstLineHeadIndent = size
        body.alignment = .justified
        body.hyphenationFactor = vertical ? 0 : 0.8
        let heading = NSMutableParagraphStyle()
        heading.lineSpacing = body.lineSpacing
        heading.paragraphSpacing = size * 2
        heading.paragraphSpacingBefore = size * 2
        heading.firstLineHeadIndent = vertical ? size * 2 : 0
        heading.alignment = vertical ? .natural : .center

        func attributes(_ font: UIFont, _ style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink.cgColor,
                .paragraphStyle: style,
            ]
            if vertical { attrs[NSAttributedString.Key(kCTVerticalFormsAttributeName as String)] = true }
            return attrs
        }
        let bodyAttrs = attributes(font(settings.typeface, size: size), body)
        let headingAttrs = attributes(font(settings.typeface, size: size * 1.35), heading)

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
                text.append(NSAttributedString(string: paragraph + "\n", attributes: bodyAttrs))
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
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: location, length: 0), path, attrs)
                // A page always takes at least one character, so a huge glyph can't stall the book.
                let visible = max(1, CTFrameGetVisibleStringRange(frame).length)
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
