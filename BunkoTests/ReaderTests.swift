import CoreGraphics
import Foundation
import Testing
@testable import Bunko

struct SpreadLayoutTests {
    @Test func rightToLeftSpreadPutsTheEarlierPageOnTheRight() {
        let layout = SpreadLayout(pageCount: 5, spread: true, rightToLeft: true)
        #expect(layout.spreadCount == 3)
        #expect(layout.paddedPageCount == 6)
        #expect(layout.pages(inSpread: 0) == [1, 0])
        #expect(layout.pages(inSpread: 2) == [5, 4])
        #expect(layout.spreadIndex(ofPage: 3) == 1)
    }

    @Test func leftToRightSpreadAndSinglePages() {
        #expect(SpreadLayout(pageCount: 4, spread: true, rightToLeft: false).pages(inSpread: 1) == [2, 3])
        let single = SpreadLayout(pageCount: 4, spread: false, rightToLeft: false)
        #expect(single.pages(inSpread: 3) == [3])
        #expect(single.spreadCount == 4)
    }

    @Test func readPagesPileUpOnTheSideYouCameFrom() {
        let rtl = SpreadLayout(pageCount: 11, spread: true, rightToLeft: true)
        #expect(rtl.edgeFractions(atPage: 0) == (left: 1, right: 0))
        #expect(rtl.edgeFractions(atPage: 10) == (left: 0, right: 1))
        let ltr = SpreadLayout(pageCount: 11, spread: false, rightToLeft: false)
        #expect(ltr.edgeFractions(atPage: 5) == (left: 0.5, right: 0.5))
    }

    @Test func lastPageCountsInTheLastSpread() {
        // The last spread's current page is its first, so a spread finishes a page early.
        let spread = SpreadLayout(pageCount: 10, spread: true, rightToLeft: true)
        #expect(spread.showsLastPage(atPage: 8))
        #expect(!spread.showsLastPage(atPage: 7))
        let single = SpreadLayout(pageCount: 10, spread: false, rightToLeft: true)
        #expect(single.showsLastPage(atPage: 9))
        #expect(!single.showsLastPage(atPage: 8))
        #expect(!SpreadLayout(pageCount: 0, spread: false, rightToLeft: false).showsLastPage(atPage: 0))
    }
}

struct PaginationTests {
    private func book(vertical: Bool) -> TypesetBook {
        let content = BookContent(chapters: [
            .init(title: "一", paragraphs: Array(repeating: "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。", count: 40)),
            .init(title: "二", paragraphs: Array(repeating: "Alice was beginning to get very tired of sitting by her sister.", count: 30)),
        ])
        return Typesetter.typeset(content, settings: ReaderSettings(), typeface: vertical ? .mincho : .serif, vertical: vertical)
    }

    @Test(arguments: [true, false])
    func pagesCoverTheWholeBookInOrder(vertical: Bool) {
        let typeset = book(vertical: vertical)
        let pages = Paginator.pages(typeset, size: CGSize(width: 300, height: 520), vertical: vertical)
        #expect(pages.count > 4)
        #expect(pages.first?.location == 0)
        for (a, b) in zip(pages, pages.dropFirst()) { #expect(a.location + a.length == b.location) }
        #expect(pages.last.map { $0.location + $0.length } == typeset.text.length)
        // The second chapter starts a page of its own.
        #expect(pages.contains { $0.location == typeset.chapterStarts[1] })
    }

    @Test func findsThePageForAnOffset() {
        let pages = [NSRange(location: 0, length: 10), NSRange(location: 10, length: 10), NSRange(location: 20, length: 5)]
        #expect(Paginator.page(containing: 0, in: pages) == 0)
        #expect(Paginator.page(containing: 15, in: pages) == 1)
        #expect(Paginator.page(containing: 99, in: pages) == 2)
        #expect(Paginator.page(containing: 3, in: []) == 0)
    }

    @Test func spreadOnlyOnWideScreens() {
        let settings = ReaderSettings()
        #expect(!settings.usesSpread(in: CGSize(width: 402, height: 874)))
        #expect(settings.usesSpread(in: CGSize(width: 874, height: 402)))
        var never = settings
        never.spread = .never
        #expect(!never.usesSpread(in: CGSize(width: 900, height: 600)))
    }
}

struct OPDSTests {
    private let feed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog">
      <title>BasilNet</title>
      <link rel="next" href="/opds/new?page=2" type="application/atom+xml;profile=opds-catalog"/>
      <entry>
        <title>Authors</title><id>authors</id>
        <link type="application/atom+xml;profile=opds-catalog" href="authors"/>
      </entry>
      <entry>
        <title>吾輩は猫である</title><id>urn:book:1</id>
        <author><name>夏目漱石</name></author>
        <summary>A cat &amp; his people.</summary>
        <link rel="alternate" type="application/atom+xml" href="/opds/book/1"/>
        <link rel="http://opds-spec.org/acquisition" type="application/pdf" href="/download/1/pdf"/>
        <link rel="http://opds-spec.org/acquisition/open-access" type="application/epub+zip" href="/download/1/epub"/>
      </entry>
    </feed>
    """

    @Test func parsesShelvesBooksAndPaging() throws {
        let parsed = try OPDSParser.parse(Data(feed.utf8), base: URL(string: "http://basilnet.local:8083/opds/")!)
        #expect(parsed.title == "BasilNet")
        #expect(parsed.next?.absoluteString == "http://basilnet.local:8083/opds/new?page=2")
        #expect(parsed.entries.count == 2)
        #expect(parsed.entries[0].navigation?.absoluteString == "http://basilnet.local:8083/opds/authors")
        let book = parsed.entries[1]
        #expect(book.navigation == nil)
        #expect(book.author == "夏目漱石")
        #expect(book.summary == "A cat & his people.")
        #expect(book.download?.href.absoluteString == "http://basilnet.local:8083/download/1/epub")
    }

    @Test func notAFeed() {
        #expect(throws: OPDSParser.Failure.self) { try OPDSParser.parse(Data("<html/>".utf8), base: URL(string: "http://x")!) }
    }

    @Test func addressesBecomeFeedURLs() {
        #expect(Bookshop.feedURL(from: "basilnet.local:8083")?.absoluteString == "http://basilnet.local:8083/opds")
        #expect(Bookshop.feedURL(from: " https://books.example.com/api/opds/KEY ")?.absoluteString == "https://books.example.com/api/opds/KEY")
        #expect(Bookshop.feedURL(from: "") == nil)
    }
}

@MainActor
struct SyncStoreTests {
    final class MemoryCloud: KeyValueCloud {
        var store: [String: Data] = [:]
        var handler: (([String]) -> Void)?
        func data(forKey key: String) -> Data? { store[key] }
        func set(_ data: Data, forKey key: String) { store[key] = data }
        var keys: [String] { Array(store.keys) }
        func synchronize() {}
        func onExternalChange(_ handler: @escaping ([String]) -> Void) { self.handler = handler }
    }

    private func defaults() -> UserDefaults {
        let name = "bunko-tests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func newerCopyFromAnotherDeviceWins() {
        let cloud = MemoryCloud()
        let phone = SyncStore(defaults: defaults(), cloud: cloud)
        let ipad = SyncStore(defaults: defaults(), cloud: cloud)
        phone.set(ReadingProgress(offset: 10, ribbon: 10, fraction: 0.1), "progress.x", at: Date(timeIntervalSince1970: 100))
        ipad.merge(["sync.progress.x"])
        #expect(ipad.value(ReadingProgress.self, "progress.x")?.offset == 10)

        // An older write elsewhere doesn't undo a newer one here.
        ipad.set(ReadingProgress(offset: 50, ribbon: 50, fraction: 0.5), "progress.x", at: Date(timeIntervalSince1970: 300))
        phone.set(ReadingProgress(offset: 30, ribbon: 30, fraction: 0.3), "progress.x", at: Date(timeIntervalSince1970: 200))
        ipad.merge(["sync.progress.x"])
        #expect(ipad.value(ReadingProgress.self, "progress.x")?.offset == 50)
    }

    @Test func syncOffStaysLocal() {
        let cloud = MemoryCloud()
        let store = SyncStore(defaults: defaults(), cloud: cloud)
        store.iCloudEnabled = false
        store.settings.fontSize = 22
        #expect(store.settings.fontSize == 22)
        #expect(cloud.store.isEmpty)
    }

    @Test func settingsFromAnOlderVersionKeepDefaults() throws {
        let old = try JSONDecoder().decode(ReaderSettings.self, from: Data(#"{"fontSize": 20, "paper": "night"}"#.utf8))
        #expect(old.fontSize == 20)
        #expect(old.paper == .night)
        #expect(old.typeface == .mincho)
        #expect(old.ribbonColor == ReaderSettings().ribbonColor)
    }
}
