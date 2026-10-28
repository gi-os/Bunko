import Foundation
import Testing
@testable import Bunko

struct WidgetLinkTests {
    @Test func bookLinksRoundTrip() {
        let url = BunkoLink.url(book: "3fa9c01b77e2d410")
        #expect(url.absoluteString == "bunko://book/3fa9c01b77e2d410")
        #expect(BunkoLink.bookID(from: url) == "3fa9c01b77e2d410")
    }

    @Test func otherURLsAreNotBookLinks() {
        #expect(BunkoLink.bookID(from: URL(string: "file:///tmp/book/neko.epub")!) == nil)
        #expect(BunkoLink.bookID(from: URL(string: "bunko://shelf/abc")!) == nil)
        #expect(BunkoLink.bookID(from: URL(string: "bunko://book/")!) == nil)
    }

    @Test func currentBookSavesAndLoads() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(CurrentBook.load(from: folder) == nil)
        let book = CurrentBook(id: "n", title: "吾輩は猫である", author: "夏目漱石", rightToLeft: true, ribbonColor: "A8322D")
        book.save(cover: Data([1, 2, 3]), to: folder)
        let loaded = try #require(CurrentBook.load(from: folder))
        #expect(loaded.book == book)
        #expect(loaded.cover == Data([1, 2, 3]))
    }

    @Test @MainActor func widgetLinksAskTheShelfForTheBook() {
        let opener = Opener()
        #expect(!opener.open(URL(string: "file:///tmp/alice.txt")!))
        #expect(opener.request == nil)
        #expect(opener.open(BunkoLink.url(book: "abc")))
        #expect(opener.request == "abc")
    }
}
