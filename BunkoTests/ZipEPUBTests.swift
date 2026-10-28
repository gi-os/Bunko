import Compression
import Foundation
import Testing
@testable import Bunko

/// Writes small ZIPs (stored or deflated) so the reader can be tested without fixture files.
enum ZipWriter {
    static func make(_ files: [(String, String)], deflate: Bool = true) -> Data {
        var out = Data()
        var central = Data()
        func le16(_ v: Int) -> Data { Data([UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF)]) }
        func le32(_ v: Int) -> Data { le16(v & 0xFFFF) + le16(v >> 16 & 0xFFFF) }
        for (name, text) in files {
            let raw = Data(text.utf8)
            var body = raw
            var method = 0
            if deflate, name != "mimetype" {
                let capacity = raw.count + 64
                var buffer = [UInt8](repeating: 0, count: capacity)
                let n = raw.withUnsafeBytes { src in
                    compression_encode_buffer(&buffer, capacity, src.bindMemory(to: UInt8.self).baseAddress!, raw.count, nil, COMPRESSION_ZLIB)
                }
                if n > 0 { body = Data(buffer[0..<n]); method = 8 }
            }
            let nameData = Data(name.utf8)
            let offset = out.count
            out += le32(0x0403_4B50) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0) + le32(0)
            out += le32(body.count) + le32(raw.count) + le16(nameData.count) + le16(0) + nameData + body
            central += le32(0x0201_4B50) + le16(20) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0) + le32(0)
            central += le32(body.count) + le32(raw.count) + le16(nameData.count) + le16(0) + le16(0) + le16(0) + le16(0)
            central += le32(0) + le32(offset) + nameData
        }
        let centralOffset = out.count
        out += central
        out += le32(0x0605_4B50) + le16(0) + le16(0) + le16(files.count) + le16(files.count)
        out += le32(central.count) + le32(centralOffset) + le16(0)
        return out
    }

    static func epub(title: String = "坊っちゃん", rtl: Bool = true, chapters: [String]) -> Data {
        var files: [(String, String)] = [
            ("mimetype", "application/epub+zip"),
            ("META-INF/container.xml", """
            <?xml version="1.0"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
            </container>
            """),
        ]
        let items = chapters.indices.map { "<item id=\"c\($0)\" href=\"text/ch%20\($0).xhtml\" media-type=\"application/xhtml+xml\"/>" }
        let refs = chapters.indices.map { "<itemref idref=\"c\($0)\"/>" }
        files.append(("OEBPS/content.opf", """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title><dc:creator>夏目漱石</dc:creator><dc:language>ja</dc:language>
          </metadata>
          <manifest>\(items.joined())<item id="img" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/></manifest>
          <spine page-progression-direction="\(rtl ? "rtl" : "ltr")">\(refs.joined())</spine>
        </package>
        """))
        for (i, chapter) in chapters.enumerated() { files.append(("OEBPS/text/ch \(i).xhtml", chapter)) }
        files.append(("OEBPS/images/cover.jpg", "JPEG"))
        return make(files)
    }
}

struct ZipArchiveTests {
    @Test(arguments: [true, false])
    func readsStoredAndDeflatedFiles(deflate: Bool) throws {
        let long = String(repeating: "吾輩は猫である。", count: 200)
        let zip = try ZipArchive(data: ZipWriter.make([("a.txt", "hello"), ("dir/b.txt", long)], deflate: deflate))
        #expect(String(decoding: try zip.data("a.txt"), as: UTF8.self) == "hello")
        #expect(String(decoding: try zip.data("dir/b.txt"), as: UTF8.self) == long)
        #expect(throws: ZipArchive.Failure.missing("nope")) { try zip.data("nope") }
    }

    @Test func rejectsNonZip() {
        #expect(throws: ZipArchive.Failure.notZip) { try ZipArchive(data: Data("not a zip at all, sorry".utf8)) }
    }
}

struct EPUBTests {
    @Test func readsMetadataSpineAndCover() throws {
        let epub = try EPUB(data: ZipWriter.epub(chapters: ["<html><body><p>一</p></body></html>", "<p>二</p>"]))
        #expect(epub.title == "坊っちゃん")
        #expect(epub.author == "夏目漱石")
        #expect(epub.language == "ja")
        #expect(epub.rightToLeft)
        #expect(epub.chapterPaths == ["OEBPS/text/ch 0.xhtml", "OEBPS/text/ch 1.xhtml"])
        #expect(epub.coverImageData() == Data("JPEG".utf8))
    }

    @Test func chaptersBecomeParagraphsWithTitles() throws {
        let chapter = """
        <?xml version="1.0" encoding="utf-8"?>
        <html><head><title>ignored</title><style>p{}</style></head><body>
        <h1>一</h1>
        <p>親譲りの<ruby>無鉄砲<rt>むてっぽう</rt></ruby>で
        小供の時から損ばかりしている。</p>
        <p>Tom &amp; Jerry&nbsp;&#x2014; &#12354;</p>
        </body></html>
        """
        let content = try EPUB(data: ZipWriter.epub(chapters: [chapter])).content()
        #expect(content.chapters.count == 1)
        #expect(content.chapters[0].title == "一")
        #expect(content.chapters[0].paragraphs == ["親譲りの無鉄砲で小供の時から損ばかりしている。", "Tom & Jerry — あ"])
    }

    @Test func resolvesRelativeHrefs() {
        #expect(EPUB.resolve("../text/a%20b.xhtml#p1", base: "OEBPS/nav") == "OEBPS/text/a b.xhtml")
        #expect(EPUB.resolve("c.xhtml", base: "") == "c.xhtml")
    }
}

struct TextTests {
    @Test func aozoraMarkupIsRemoved() {
        let content = PlainText.content("　｜吾輩《わがはい》は猫である。［＃「猫」に傍点］\n\n名前はまだ無い。\n")
        #expect(content.chapters[0].paragraphs == ["吾輩は猫である。", "名前はまだ無い。"])
    }

    @Test func detectsJapanese() {
        #expect(Script.looksJapanese("吾輩は猫である。名前はまだ無い。"))
        #expect(!Script.looksJapanese("Alice was beginning to get very tired."))
    }

    @Test func englishLineBreaksBecomeSpaces() {
        #expect(HTMLText.collapse("one\n  two") == "one two")
        #expect(HTMLText.collapse("猫\nである") == "猫である")
    }

    @Test func stableIDsIgnoreCase() {
        #expect(Book.stableID(title: "Alice", author: "Carroll") == Book.stableID(title: "alice", author: "carroll"))
        #expect(Book.stableID(title: "Alice", author: "") != Book.stableID(title: "Alice", author: "Carroll"))
    }
}
