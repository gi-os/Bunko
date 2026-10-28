import CoreText
import UIKit

/// Horizontal text, set a line at a time. CoreText's framesetter can't hyphenate, so lines are
/// broken here: a word that won't fit is split at a hyphenation point from the system's
/// dictionaries for the book's language, and the line ends in a real hyphen. Every line but a
/// paragraph's last is justified, unless that would open rivers between the words (then it stays
/// ragged). The paginator and the page both lay lines with this, so a page draws exactly the
/// lines it was cut with. Vertical text keeps the framesetter.
enum LineSetter {
    struct Line {
        /// Characters in the chapter's string, including trailing spaces and the newline.
        var range: CFRange
        var line: CTLine
        /// Baseline start, in the text rect with y growing down.
        var origin: CGPoint
        var width: CGFloat
        var hyphenated: Bool
    }

    /// Lines from `start` until the page is full or `limit` is reached; `next` is where the
    /// following page starts.
    static func lay(_ text: NSAttributedString, typesetter: CTTypesetter, from start: Int, limit: Int? = nil,
                    size: CGSize) -> (lines: [Line], next: Int) {
        let string = text.string as NSString
        let end = min(limit ?? string.length, string.length)
        let locale = hyphenationLocale(text, at: start)
        var lines: [Line] = []
        var position = start
        var top: CGFloat = 0
        while position < end {
            let style = text.attribute(.paragraphStyle, at: position, effectiveRange: nil) as? NSParagraphStyle ?? .default
            let font = text.attribute(.font, at: position, effectiveRange: nil) as? UIFont ?? .systemFont(ofSize: 17)
            let opensParagraph = position == 0 || string.character(at: position - 1) == newline
            let before = opensParagraph && !lines.isEmpty ? style.paragraphSpacingBefore : 0
            let indent = opensParagraph ? style.firstLineHeadIndent : style.headIndent
            let available = max(1, size.width - indent)
            let rightToLeft = style.baseWritingDirection == .rightToLeft

            var lineEnd = min(string.length, position + max(1, CTTypesetterSuggestLineBreak(typesetter, position, Double(available))))
            let closesParagraph = lineEnd >= string.length || string.character(at: lineEnd - 1) == newline
            var hyphenated = false
            if !closesParagraph, style.hyphenationFactor > 0, let locale,
               let split = hyphenate(text, string, lineFrom: position, wordAt: lineEnd, width: available, locale: locale) {
                lineEnd = split
                hyphenated = true
            }

            var (line, gaps) = makeLine(text, string, from: position, to: lineEnd, hyphen: hyphenated)
            var width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            // Justify unless each space would have to stretch past about half an em.
            if !closesParagraph, style.alignment == .justified, gaps > 0, width < available,
               available - width <= font.pointSize * 0.5 * CGFloat(gaps),
               let justified = CTLineCreateJustifiedLine(line, 1, Double(available)) {
                line = justified
                width = available
            }

            let ascent = font.ascender, descent = -font.descender
            if !lines.isEmpty && top + before + ascent + descent > size.height { break }
            top += before
            let leftInset = rightToLeft ? 0 : indent
            let x: CGFloat = switch style.alignment {
            case .center: leftInset + (available - width) / 2
            case .right: leftInset + available - width
            default: rightToLeft ? leftInset + available - width : leftInset
            }
            lines.append(Line(range: CFRange(location: position, length: lineEnd - position), line: line,
                              origin: CGPoint(x: x, y: top + ascent), width: width, hyphenated: hyphenated))
            top += ascent + descent + style.lineSpacing
            if closesParagraph { top += style.paragraphSpacing }
            position = lineEnd
        }
        return (lines, max(position, start + 1))
    }

    private static let newline = UInt16(UnicodeScalar("\n").value)

    private static func hyphenationLocale(_ text: NSAttributedString, at index: Int) -> CFLocale? {
        guard index < text.length,
              let language = text.attribute(NSAttributedString.Key(kCTLanguageAttributeName as String), at: index,
                                            effectiveRange: nil) as? String,
              !language.isEmpty else { return nil }
        let locale = Locale(identifier: language) as CFLocale
        return CFStringIsHyphenationAvailableForLocale(locale) ? locale : nil
    }

    /// Where to split the word that didn't fit, so its first part and a hyphen end this line:
    /// the latest hyphenation point that fits, keeping two letters before it and three after.
    private static func hyphenate(_ text: NSAttributedString, _ string: NSString, lineFrom start: Int, wordAt wordStart: Int,
                                  width: CGFloat, locale: CFLocale) -> Int? {
        guard wordStart > start, let gap = UnicodeScalar(string.character(at: wordStart - 1)),
              CharacterSet.whitespaces.contains(gap) else { return nil }
        var wordEnd = wordStart
        while wordEnd < string.length, isLetter(string.character(at: wordEnd)) { wordEnd += 1 }
        guard wordEnd - wordStart >= 5 else { return nil }
        let word = CFRange(location: wordStart, length: wordEnd - wordStart)
        var before = wordEnd - 2
        while before > wordStart + 2 {
            let point = CFStringGetHyphenationLocationBeforeIndex(string, before, word, 0, locale, nil)
            guard point != kCFNotFound, point >= wordStart + 2, point < before else { return nil }
            if wordEnd - point >= 3 {
                let trial = makeLine(text, string, from: start, to: point, hyphen: true).line
                if CGFloat(CTLineGetTypographicBounds(trial, nil, nil, nil)) <= width { return point }
            }
            before = point
        }
        return nil
    }

    private static func isLetter(_ unit: unichar) -> Bool {
        guard let scalar = UnicodeScalar(unit) else { return false }
        return CharacterSet.letters.contains(scalar)
    }

    /// The line as drawn: without its trailing spaces and newline, with a hyphen when it splits a
    /// word; and how many spaces it has to stretch.
    private static func makeLine(_ text: NSAttributedString, _ string: NSString, from start: Int, to end: Int,
                                 hyphen: Bool) -> (line: CTLine, gaps: Int) {
        var visibleEnd = end
        while visibleEnd > start, let scalar = UnicodeScalar(string.character(at: visibleEnd - 1)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) { visibleEnd -= 1 }
        let range = NSRange(location: start, length: visibleEnd - start)
        let piece = NSMutableAttributedString(attributedString: text.attributedSubstring(from: range))
        if hyphen, visibleEnd > start {
            piece.append(NSAttributedString(string: "-", attributes: text.attributes(at: visibleEnd - 1, effectiveRange: nil)))
        }
        let gaps = string.substring(with: range).reduce(0) { $1 == " " ? $0 + 1 : $0 }
        return (CTLineCreateWithAttributedString(piece), gaps)
    }
}
