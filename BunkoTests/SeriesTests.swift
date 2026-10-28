import Foundation
import Testing
@testable import Bunko

struct SeriesTests {
    private func book(_ title: String, series: String? = nil, index: Double? = nil, id: String? = nil) -> Book {
        Book(id: id ?? Book.stableID(title: title, author: ""), title: title, author: "", fileName: "", format: .txt,
             language: "", rightToLeft: false, addedAt: .now, series: series, seriesIndex: index)
    }

    @Test(arguments: [
        ("The Expanse, Vol. 3", "The Expanse", 3.0),
        ("Dune Book 2", "Dune", 2),
        ("Saga #4", "Saga", 4),
        ("Discworld (12)", "Discworld", 12),
        ("猫町 第2巻", "猫町", 2),
        ("猫町 3巻", "猫町", 3),
        ("猫町 第十二巻", "猫町", 12),
        ("猫町（４）", "猫町", 4),
        ("ワンピース 7", "ワンピース", 7),
    ])
    func titlesNameTheirSeries(title: String, series: String, index: Double) {
        #expect(Book.volume(fromTitle: title) == Book.Volume(series: series, index: index))
    }

    @Test(arguments: ["Fahrenheit 451", "Catch-22", "1984", "Alice's Adventures in Wonderland", "History (2019)"])
    func ordinaryTitlesAreNotSeries(title: String) {
        #expect(Book.volume(fromTitle: title) == nil)
    }

    @Test func metadataWinsOverTheTitle() {
        let b = book("Leviathan Wakes", series: "The Expanse", index: 1)
        #expect(b.volume == Book.Volume(series: "The Expanse", index: 1))
    }

    @Test func aSeriesSharesItsDesign() {
        let one = book("猫町 第1巻"), two = book("猫町 第2巻"), other = book("坊っちゃん")
        #expect(one.designKey == two.designKey)
        #expect(one.designKey != other.designKey)
        #expect(CoverStyle.automatic(for: one).paper == CoverStyle.automatic(for: two).paper)
        #expect(ObiStyle.automatic(for: one.designKey) == ObiStyle.automatic(for: two.designKey))
        #expect(House.of(one).imprint == House.of(two).imprint)
        #expect(House.of(one).colour == House.of(two).colour)
        // Numbered in the shelf code by volume.
        #expect(House.of(two).shelfCode.hasSuffix(" 2"))
    }

    @Test func theShelfKeepsASeriesTogetherInOrder() {
        // Newest first, as the library keeps them.
        let books = [book("猫町 第2巻"), book("Alice"), book("猫町 第3巻"), book("Dune"), book("猫町 第1巻")]
        #expect(ShelfOrder.arrange(books).map(\.title) == ["猫町 第1巻", "猫町 第2巻", "猫町 第3巻", "Alice", "Dune"])
    }

    @Test func epubSeriesMetadataIsRead() throws {
        func opf(_ meta: String) -> Data {
            ZipWriter.make([
                ("mimetype", "application/epub+zip"),
                ("META-INF/container.xml", """
                <?xml version="1.0"?>
                <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
                  <rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles>
                </container>
                """),
                ("content.opf", """
                <?xml version="1.0" encoding="UTF-8"?>
                <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
                  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Caliban's War</dc:title>\(meta)</metadata>
                  <manifest/><spine/>
                </package>
                """),
            ])
        }
        let calibre = try EPUB(data: opf(#"<meta name="calibre:series" content="The Expanse"/><meta name="calibre:series_index" content="2.0"/>"#))
        #expect(calibre.series == "The Expanse")
        #expect(calibre.seriesIndex == 2)
        let epub3 = try EPUB(data: opf(##"<meta property="belongs-to-collection" id="c1">The Expanse</meta><meta refines="#c1" property="group-position">2</meta>"##))
        #expect(epub3.series == "The Expanse")
        #expect(epub3.seriesIndex == 2)
        #expect(try EPUB(data: opf("")).series == nil)
    }

    @Test @MainActor func aSeriesStyleDressesVolumesAddedLater() {
        let store = SyncStore(defaults: UserDefaults(suiteName: "bunko-series-\(UUID().uuidString)")!, cloud: nil)
        let one = book("猫町 第1巻"), four = book("猫町 第4巻"), alone = book("坊っちゃん")
        var style = CoverStyle(paper: .seigaiha)
        style.obi = .noir
        store.setSeriesCover(style, for: one)
        #expect(store.cover(for: four) == style)
        #expect(store.cover(for: alone).paper != .seigaiha || store.cover(for: alone).obi == nil)
        // A volume dressed on its own keeps its own.
        store.setCover(CoverStyle(paper: .kraft), for: four)
        #expect(store.cover(for: four).paper == .kraft)
    }
}
