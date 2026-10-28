import Foundation
import Testing
@testable import Bunko

struct BookMapTests {
    private let pages = (0..<10).map { NSRange(location: $0 * 100, length: 100) }

    @Test func chaptersLandOnTheirPages() {
        let map = BookMap.make(titles: ["", "一", "二"], starts: [0, 250, 700], pages: pages)
        #expect(map.chapters == [.init(title: "一", page: 2), .init(title: "二", page: 7)])
        #expect(map.pageCount == 10)
        #expect(map.chapter(forPage: 0) == nil)
        #expect(map.chapter(forPage: 2) == 0)
        #expect(map.chapter(forPage: 6) == 0)
        #expect(map.chapter(forPage: 9) == 1)
    }

    @Test func fractionsSpanTheBook() {
        let map = BookMap(chapters: [], pageCount: 11)
        #expect(map.fraction(ofPage: 0) == 0)
        #expect(map.fraction(ofPage: 5) == 0.5)
        #expect(map.fraction(ofPage: 10) == 1)
        #expect(BookMap(chapters: [], pageCount: 1).fraction(ofPage: 0) == 0)
    }
}

struct BookInfoTests {
    private let book = Book(id: "x", title: "Neko 3", author: "Soseki", fileName: "x.epub", format: .epub,
                            language: "en", rightToLeft: false, addedAt: .now, shopID: nil)

    @Test func editsApplyButTheIDStays() {
        var info = BookInfo(book)
        info.title = "吾輩は猫である"
        info.author = "夏目漱石"
        info.language = "ja"
        info.rightToLeft = true
        info.series = "猫"
        info.seriesIndex = 2
        let edited = book.applying(info.cleaned(fallback: book))
        #expect(edited.id == "x")
        #expect(edited.title == "吾輩は猫である")
        #expect(edited.author == "夏目漱石")
        #expect(edited.rightToLeft)
        #expect(edited.volume == Book.Volume(series: "猫", index: 2))
    }

    @Test func blanksFallBack() {
        var info = BookInfo(book)
        info.title = "   "
        info.series = "  "
        info.seriesIndex = 4
        let cleaned = info.cleaned(fallback: book)
        #expect(cleaned.title == "Neko 3")
        #expect(cleaned.series == nil)
        #expect(cleaned.seriesIndex == nil)
    }

    @Test func partialCopiesDecode() throws {
        let info = try JSONDecoder().decode(BookInfo.self, from: Data(#"{"title": "Kokoro"}"#.utf8))
        #expect(info.title == "Kokoro")
        #expect(info.series == nil)
        #expect(!info.rightToLeft)
    }
}
