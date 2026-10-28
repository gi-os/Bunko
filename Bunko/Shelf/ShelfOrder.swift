import Foundation

/// The shelf's order: newest first, but a series stands together, in volume order, where its
/// newest volume would be.
enum ShelfOrder {
    static func arrange(_ books: [Book]) -> [Book] {
        let sets = Dictionary(grouping: books.filter { $0.volume != nil }, by: \.designKey)
        var placed = Set<String>()
        var shelf: [Book] = []
        for book in books where !placed.contains(book.id) {
            let set = book.volume == nil ? [book] : (sets[book.designKey] ?? [book]).sorted(by: inVolumeOrder)
            for volume in set where placed.insert(volume.id).inserted { shelf.append(volume) }
        }
        return shelf
    }

    /// By number; numbered before unnumbered; then by title.
    static func inVolumeOrder(_ a: Book, _ b: Book) -> Bool {
        switch (a.volume?.index, b.volume?.index) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
}
