import CoreText
import Foundation
import Testing
@testable import Bunko

struct LineSetterTests {
    private func alice(width: CGFloat) -> (text: NSAttributedString, lines: [LineSetter.Line]) {
        let content = BookContent(chapters: [.init(title: "", paragraphs: [
            "So she was considering in her own mind (as well as she could, for the hot day made her feel very sleepy and stupid), whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies, when suddenly a White Rabbit with pink eyes ran close by her.",
        ])])
        let text = Typesetter.typeset(content, settings: ReaderSettings(), typeface: .serif, vertical: false, language: "en").text
        let setter = CTFramesetterCreateWithAttributedString(text)
        return (text, LineSetter.lay(text, typesetter: CTFramesetterGetTypesetter(setter), from: 0, size: CGSize(width: width, height: 5000)).lines)
    }

    @Test func englishBreaksWithHyphensAndStaysInTheMeasure() {
        let (text, lines) = alice(width: 180)
        #expect(lines.contains { $0.hyphenated })
        #expect(lines.allSatisfy { $0.origin.x + $0.width <= 180.5 })
        // The lines tile the paragraph: no gaps, no overlaps.
        var next = 0
        for line in lines {
            #expect(line.range.location == next)
            next += line.range.length
        }
        #expect(next == text.length)
    }

    @Test func fullLinesAreJustifiedAndTheLastIsNot() {
        let (_, lines) = alice(width: 220)
        let full = lines.dropLast().filter { abs($0.width - 220) < 0.5 }
        #expect(full.count >= lines.count / 2)
        #expect(lines.last!.width < 220)
    }

    @Test func horizontalPagesCoverTheBook() {
        let content = BookContent(chapters: [.init(title: "I", paragraphs: Array(repeating: "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do.", count: 60))])
        let book = Typesetter.typeset(content, settings: ReaderSettings(), typeface: .serif, vertical: false, language: "en")
        let pages = Paginator.pages(book, size: CGSize(width: 320, height: 600), vertical: false)
        #expect(pages.count > 3)
        var next = 0
        for page in pages {
            #expect(page.location == next)
            next += page.length
        }
        #expect(next == book.text.length)
    }
}

struct SmartQuoteTests {
    @Test func quotesCurlAndKeepTheirLength() {
        let straight = #""and what is the use of a book," thought Alice 'without pictures?' It's"#
        let curled = SmartQuotes.curl(straight)
        #expect(curled == "\u{201C}and what is the use of a book,\u{201D} thought Alice \u{2018}without pictures?\u{2019} It\u{2019}s")
        #expect(curled.utf16.count == straight.utf16.count)
    }

    @Test func japaneseIsLeftAlone() {
        #expect(SmartQuotes.curl("吾輩は猫である。") == "吾輩は猫である。")
    }
}

struct DirectionTests {
    private func book(_ language: String) -> Book {
        Book(id: language, title: "", author: "", fileName: "", format: .txt, language: language,
             rightToLeft: Book.boundOnRight(language: language), addedAt: .now)
    }

    @Test func languageDecidesTheBinding() {
        #expect(Book.boundOnRight(language: "ja"))
        #expect(Book.boundOnRight(language: "ar-EG"))
        #expect(Book.boundOnRight(language: "he"))
        #expect(!Book.boundOnRight(language: "en"))
        #expect(!Book.boundOnRight(language: "en-GB"))
        #expect(!Book.boundOnRight(language: ""))
    }

    @Test func onlyJapaneseGoesVertical() {
        let settings = ReaderSettings()
        #expect(settings.isVertical(for: book("ja")))
        #expect(!settings.isVertical(for: book("en")))
        #expect(!settings.isVertical(for: book("ar")))
        #expect(settings.face(for: book("ar")) == settings.westernTypeface)
    }

    @Test func plainTextFindsItsLanguage() {
        #expect(Script.language(of: "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do.") == "en")
        #expect(Script.language(of: "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。") == "ja")
    }
}

struct VolumeLevelTests {
    @Test func restsAStepInFromEitherEnd() {
        #expect(VolumeLevel.resting(0) == VolumeLevel.step)
        #expect(VolumeLevel.resting(1) == 1 - VolumeLevel.step)
        #expect(VolumeLevel.resting(0.5) == 0.5)
    }

    @Test func aPressMovesItButPuttingItBackDoesNot() {
        #expect(VolumeLevel.isPress(resting: 0.5, now: 0.5 + VolumeLevel.step))
        #expect(VolumeLevel.isPress(resting: 0.5, now: 0.5 - VolumeLevel.step))
        #expect(!VolumeLevel.isPress(resting: 0.5, now: 0.5))
    }
}
