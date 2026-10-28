import Foundation

/// An EPUB 2 or 3 book: its metadata, reading order and cover, read straight from the ZIP.
struct EPUB {
    enum Failure: Error { case noPackage }

    var title: String
    var author: String
    var language: String
    var rightToLeft: Bool
    var chapterPaths: [String]
    var coverPath: String?
    private let zip: ZipArchive

    init(data: Data) throws {
        zip = try ZipArchive(data: data)
        guard let container = XNode.parse(try zip.data("META-INF/container.xml")),
              let opfPath = container.firstDescendant("rootfile")?["full-path"],
              let package = XNode.parse(try zip.data(opfPath))
        else { throw Failure.noPackage }

        let base = (opfPath as NSString).deletingLastPathComponent
        let metadata = package.first("metadata")
        title = metadata?.first("title")?.trimmedText ?? ""
        author = metadata?.all("creator").map(\.trimmedText).filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
        language = metadata?.first("language")?.trimmedText ?? ""

        var manifest: [String: (href: String, properties: String)] = [:]
        for item in package.first("manifest")?.all("item") ?? [] {
            guard let id = item["id"], let href = item["href"] else { continue }
            manifest[id] = (Self.resolve(href, base: base), item["properties"] ?? "")
        }
        let spine = package.first("spine")
        chapterPaths = (spine?.all("itemref") ?? []).compactMap { ref in ref["idref"].flatMap { manifest[$0]?.href } }
        rightToLeft = spine?["page-progression-direction"] == "rtl"

        if let cover = manifest.values.first(where: { $0.properties.split(separator: " ").contains("cover-image") }) {
            coverPath = cover.href
        } else if let id = metadata?.all("meta").first(where: { $0["name"] == "cover" })?["content"] {
            coverPath = manifest[id]?.href
        }
    }

    func content() -> BookContent {
        var chapters: [BookContent.Chapter] = []
        for path in chapterPaths {
            guard let data = try? zip.data(path), let html = PlainText.decode(data) else { continue }
            let text = HTMLText.extract(html)
            guard !text.paragraphs.isEmpty else { continue }
            chapters.append(.init(title: text.title ?? "", paragraphs: text.paragraphs))
        }
        return BookContent(chapters: chapters)
    }

    func coverImageData() -> Data? {
        coverPath.flatMap { try? zip.data($0) }
    }

    /// A manifest href, relative to the package file, as a path inside the ZIP.
    static func resolve(_ href: String, base: String) -> String {
        let clean = (href.split(separator: "#", maxSplits: 1).first.map(String.init) ?? href)
        let decoded = clean.removingPercentEncoding ?? clean
        var parts: [Substring] = base.isEmpty ? [] : base.split(separator: "/")
        for part in decoded.split(separator: "/") {
            if part == ".." { _ = parts.popLast() } else if part != "." { parts.append(part) }
        }
        return parts.joined(separator: "/")
    }
}
