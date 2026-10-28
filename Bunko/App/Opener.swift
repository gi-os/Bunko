import Foundation
import Observation

/// Asks the shelf to pick a book up, on its cover: tapping the widget (bunko://book/<id>) or the
/// "Read instead" shortcut. The shelf watches `request` and clears it once the book is in hand.
@MainActor @Observable
final class Opener {
    static let shared = Opener()

    var request: String?

    /// The book last opened: the one the widget shows and "Read instead" hands you.
    static let currentKey = "bunko.current"

    static var currentBookID: String? { UserDefaults.standard.string(forKey: currentKey) }

    static func setCurrent(_ id: String) { UserDefaults.standard.set(id, forKey: currentKey) }

    func open(_ url: URL) -> Bool {
        guard let id = BunkoLink.bookID(from: url) else { return false }
        request = id
        return true
    }

    func openCurrentBook() {
        if let id = Self.currentBookID { request = id }
    }
}
