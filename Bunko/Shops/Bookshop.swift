import Foundation
import Security

/// A book server you read from: Calibre, Calibre-Web, Kavita, Komga, anything with an OPDS feed.
/// The list syncs through iCloud; the password lives in the (iCloud) Keychain.
struct Bookshop: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var feedURL: URL
    var username: String
    /// Printed on the paper cover of every book that comes from here.
    var stamp: String

    /// What people type ("basilnet.local:8083", "https://books.example.com/opds") as a feed URL:
    /// http:// when there's no scheme, and /opds (Calibre and Calibre-Web) when there's no path.
    static func feedURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var parts = URLComponents(string: text), let host = parts.host, !host.isEmpty else { return nil }
        if parts.path.isEmpty || parts.path == "/" { parts.path = "/opds" }
        return parts.url
    }
}

enum Keychain {
    private static let service = "com.gios.bunko.bookshop"

    static func setPassword(_ password: String, for id: UUID) {
        delete(id)
        guard !password.isEmpty else { return }
        let item: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString,
            kSecAttrSynchronizable: true,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: Data(password.utf8),
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func password(for id: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ id: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
