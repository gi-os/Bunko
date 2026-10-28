import SwiftUI
import WidgetKit

struct CurrentBookWidgetView: View {
    let entry: CurrentBookEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(entry.book.map { BunkoLink.url(book: $0.id) })
            .containerBackground(for: .widget) {
                if family == .systemSmall { ShelfBackground() } else { Color.clear }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryRectangular: lockScreen
        default: shelf
        }
    }

    /// Home Screen: the book standing on the shelf's pale wood.
    private var shelf: some View {
        Group {
            if let book = entry.book, let cover = entry.cover {
                BookFace(cover: cover, rightToLeft: book.rightToLeft)
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
                    .accessibilityLabel(book.title)
            } else {
                Text("文庫")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "8A3A2E").opacity(0.6))
                    .accessibilityLabel("Bunko")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Lock Screen: a small cover beside the title.
    private var lockScreen: some View {
        HStack(spacing: 8) {
            if let book = entry.book {
                if let cover = entry.cover {
                    BookFace(cover: cover, rightToLeft: book.rightToLeft)
                        .padding(.bottom, 6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.headline).lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Bunko").font(.headline)
            }
        }
    }
}

/// A closed book seen from the front, in a bunko's 105:148, rounder at the fore-edge than the
/// spine, its page block showing past the fore-edge and foot.
struct BookFace: View {
    let cover: UIImage
    let rightToLeft: Bool

    var body: some View {
        Image(uiImage: cover)
            .resizable()
            .aspectRatio(105.0 / 148.0, contentMode: .fit)
            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: rightToLeft ? 3 : 1, bottomLeading: rightToLeft ? 3 : 1,
                bottomTrailing: rightToLeft ? 1 : 3, topTrailing: rightToLeft ? 1 : 3)))
            .bookDepth(spineOnRight: rightToLeft, depth: 3)
    }
}
