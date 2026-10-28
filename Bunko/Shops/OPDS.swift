import Foundation

/// One page of an OPDS 1.x (Atom) catalog: either shelves to go into, or books to download.
struct OPDSFeed: Equatable {
    struct Link: Equatable {
        var href: URL
        var type: String
        var rel: String
    }

    struct Entry: Identifiable, Equatable {
        var id: String
        var title: String
        var author: String
        var summary: String
        /// A deeper catalog page (a shelf, an author, a series).
        var navigation: URL?
        var acquisitions: [Link]

        /// The file Bunko can read: EPUB first, then plain text.
        var download: Link? {
            acquisitions.first { $0.type.hasPrefix("application/epub+zip") }
                ?? acquisitions.first { $0.href.pathExtension.lowercased() == "epub" }
                ?? acquisitions.first { $0.type.hasPrefix("text/plain") }
        }
    }

    var title: String
    var entries: [Entry]
    var next: URL?
}

enum OPDSParser {
    enum Failure: Error { case notAFeed }

    static func parse(_ data: Data, base: URL) throws -> OPDSFeed {
        guard let root = XNode.parse(data), root.name == "feed" else { throw Failure.notAFeed }
        func url(_ link: XNode) -> URL? {
            link["href"].flatMap { URL(string: $0, relativeTo: base)?.absoluteURL }
        }
        let entries = root.all("entry").enumerated().map { index, entry -> OPDSFeed.Entry in
            var navigation: URL?
            var acquisitions: [OPDSFeed.Link] = []
            for link in entry.all("link") {
                guard let href = url(link) else { continue }
                let rel = link["rel"] ?? ""
                let type = link["type"] ?? ""
                if rel.hasPrefix("http://opds-spec.org/acquisition") {
                    acquisitions.append(.init(href: href, type: type, rel: rel))
                } else if type.contains("atom+xml"), navigation == nil, rel != "alternate" || acquisitions.isEmpty {
                    navigation = href
                }
            }
            let summaryNode = entry.first("summary") ?? entry.first("content")
            let summary = summaryNode.map { HTMLText.extract($0.text).paragraphs.joined(separator: " ") } ?? ""
            return OPDSFeed.Entry(
                id: entry.first("id")?.trimmedText ?? "\(index)",
                title: entry.first("title")?.trimmedText ?? "Untitled",
                author: entry.all("author").compactMap { $0.first("name")?.trimmedText }.joined(separator: ", "),
                summary: summary,
                navigation: acquisitions.isEmpty ? navigation : nil,
                acquisitions: acquisitions
            )
        }
        let next = root.all("link").first { $0["rel"] == "next" }.flatMap(url)
        return OPDSFeed(title: root.first("title")?.trimmedText ?? "", entries: entries, next: next)
    }
}

/// Fetches catalog pages and books, answering Basic and Digest challenges (Calibre's content
/// server uses Digest over plain HTTP) with the bookshop's login.
final class OPDSClient: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    enum Failure: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(401), .http(403): "The server didn't accept that username and password."
            case .http(404): "Nothing at that address. Calibre and Calibre-Web serve their catalog at /opds."
            case .http(let code): "The server answered \(code)."
            }
        }
    }

    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    convenience init(shop: Bookshop) {
        self.init(username: shop.username, password: Keychain.password(for: shop.id) ?? "")
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/atom+xml, application/xml;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request, delegate: self)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure.http(http.statusCode)
        }
        return data
    }

    func feed(at url: URL) async throws -> OPDSFeed {
        try OPDSParser.parse(try await data(from: url), base: url)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let method = challenge.protectionSpace.authenticationMethod
        let login = method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodHTTPDigest
        if login, !username.isEmpty, challenge.previousFailureCount == 0 {
            return (.useCredential, URLCredential(user: username, password: password, persistence: .forSession))
        }
        return (.performDefaultHandling, nil)
    }
}
