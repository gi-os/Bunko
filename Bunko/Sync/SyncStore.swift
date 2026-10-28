import Foundation
import Observation

/// The iCloud key-value store, behind a protocol so tests can use an in-memory one.
protocol KeyValueCloud: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    var keys: [String] { get }
    func synchronize()
    /// Calls back with the keys another device changed.
    func onExternalChange(_ handler: @escaping ([String]) -> Void)
}

final class UbiquitousCloud: KeyValueCloud {
    private let store = NSUbiquitousKeyValueStore.default

    func data(forKey key: String) -> Data? { store.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { store.set(data, forKey: key) }
    var keys: [String] { Array(store.dictionaryRepresentation.keys) }
    func synchronize() { store.synchronize() }

    func onExternalChange(_ handler: @escaping ([String]) -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { note in
            handler(note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? [])
        }
    }
}

/// The small things that follow you between devices: reading position and ribbon per book, paper
/// covers, reader settings and bookshops. Kept in UserDefaults so everything works offline and
/// with sync off, and mirrored to iCloud when it's on. Every value carries the time it was
/// written, and the newer copy wins.
@MainActor @Observable
final class SyncStore {
    static let shared = SyncStore()

    private struct Stamped: Codable {
        var at: Date
        var value: Data
    }

    /// Bumped on every change, here or from another device; the typed accessors read it so views
    /// that show synced values refresh.
    private(set) var revision = 0

    var iCloudEnabled: Bool {
        didSet {
            defaults.set(iCloudEnabled, forKey: Self.enabledKey)
            if iCloudEnabled { pullFromCloud(); pushToCloud() }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let cloud: KeyValueCloud?
    private static let enabledKey = "bunko.icloud"
    private static let prefix = "sync."

    init(defaults: UserDefaults = .standard, cloud: KeyValueCloud? = UbiquitousCloud()) {
        self.defaults = defaults
        self.cloud = cloud
        iCloudEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        cloud?.onExternalChange { [weak self] keys in
            MainActor.assumeIsolated { self?.merge(keys) }
        }
        if iCloudEnabled {
            cloud?.synchronize()
            pullFromCloud()
            pushToCloud()
        }
    }

    func value<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        _ = revision
        guard let stamped = stamped(defaults.data(forKey: Self.prefix + key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: stamped.value)
    }

    func set<T: Encodable>(_ value: T, _ key: String, at date: Date = .now) {
        guard let body = try? JSONEncoder().encode(value),
              let data = try? JSONEncoder().encode(Stamped(at: date, value: body)) else { return }
        defaults.set(data, forKey: Self.prefix + key)
        if iCloudEnabled { cloud?.set(data, forKey: Self.prefix + key) }
        revision += 1
    }

    /// Takes the copies from iCloud that are newer than ours.
    func merge(_ keys: [String]) {
        guard iCloudEnabled, let cloud else { return }
        var changed = false
        for key in keys where key.hasPrefix(Self.prefix) {
            guard let data = cloud.data(forKey: key), let remote = stamped(data) else { continue }
            if let local = stamped(defaults.data(forKey: key)), local.at >= remote.at { continue }
            defaults.set(data, forKey: key)
            changed = true
        }
        if changed { revision += 1 }
    }

    private func pullFromCloud() {
        guard let cloud else { return }
        merge(cloud.keys)
    }

    /// Sends what's newer here (written while sync was off, or offline).
    private func pushToCloud() {
        guard let cloud else { return }
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(Self.prefix) {
            guard let data = value as? Data, let local = stamped(data) else { continue }
            if let remote = stamped(cloud.data(forKey: key)), remote.at >= local.at { continue }
            cloud.set(data, forKey: key)
        }
    }

    private func stamped(_ data: Data?) -> Stamped? {
        data.flatMap { try? JSONDecoder().decode(Stamped.self, from: $0) }
    }
}

// The synced values, by name.
extension SyncStore {
    var settings: ReaderSettings {
        get { value(ReaderSettings.self, "settings") ?? ReaderSettings() }
        set { set(newValue, "settings") }
    }

    var shops: [Bookshop] {
        get { value([Bookshop].self, "shops") ?? [] }
        set { set(newValue, "shops") }
    }

    func progress(for book: Book) -> ReadingProgress? {
        value(ReadingProgress.self, "progress.\(book.id)")
    }

    func setProgress(_ progress: ReadingProgress, for book: Book) {
        set(progress, "progress.\(book.id)")
    }

    func storedCover(for book: Book) -> CoverStyle? {
        value(CoverStyle.self, "cover.\(book.id)")
    }

    func cover(for book: Book) -> CoverStyle {
        storedCover(for: book)
            ?? CoverStyle.automatic(for: book, shopStamp: shops.first { $0.id == book.shopID }?.stamp)
    }

    func setCover(_ style: CoverStyle, for book: Book) {
        set(style, "cover.\(book.id)")
    }
}
