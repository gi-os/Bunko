import SwiftUI
import WidgetKit

@main
struct BunkoWidgets: WidgetBundle {
    var body: some Widget {
        CurrentBookWidget()
    }
}

/// The book you're reading, in its cover as it looks now, the ribbon's tail out of its foot. Tap
/// it and the book opens on its cover. The app draws the cover and writes it to the App Group
/// (CurrentBook) when it goes to the background, and asks for a reload then.
struct CurrentBookWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurrentBook", provider: CurrentBookProvider()) { entry in
            CurrentBookWidgetView(entry: entry)
        }
        .configurationDisplayName("Your Book")
        .description("The book you're reading, in its cover. Tap to pick it up.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct CurrentBookEntry: TimelineEntry {
    var date = Date.now
    var book: CurrentBook?
    var cover: UIImage?
}

struct CurrentBookProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentBookEntry { CurrentBookEntry() }

    func getSnapshot(in context: Context, completion: @escaping (CurrentBookEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentBookEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> CurrentBookEntry {
        guard let current = CurrentBook.load() else { return CurrentBookEntry() }
        return CurrentBookEntry(book: current.book, cover: current.cover.flatMap(UIImage.init(data:)))
    }
}
