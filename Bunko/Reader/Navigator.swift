import SwiftUI
import UIKit

/// Where the chapters fall among the pages, for flicking through the book.
struct BookMap: Equatable {
    struct Chapter: Equatable {
        var title: String
        var page: Int
    }

    var chapters: [Chapter]
    var pageCount: Int

    /// Chapters (with a title) by the page each starts on.
    static func make(titles: [String], starts: [Int], pages: [NSRange]) -> BookMap {
        let chapters = zip(titles, starts).compactMap { title, start -> Chapter? in
            title.isEmpty ? nil : Chapter(title: title, page: Paginator.page(containing: start, in: pages))
        }
        return BookMap(chapters: chapters, pageCount: pages.count)
    }

    /// The chapter a page is in, or nil before the first.
    func chapter(forPage page: Int) -> Int? {
        chapters.lastIndex { $0.page <= page }
    }

    func fraction(ofPage page: Int) -> Double {
        pageCount <= 1 ? 0 : Double(page) / Double(pageCount - 1)
    }
}

/// Two fingers tap the page: the book's chapters and a scrubber to flick through it, on a paper
/// band at the foot of the page. The pages behind follow as you scrub; tap the page above the
/// band to go back to reading.
struct NavigatorView: View {
    let model: ReaderModel
    @State private var scrub: Double = 0
    @State private var startPage = 0
    @State private var lastChapter: Int?

    private var map: BookMap { model.bookMap }
    private var japanese: Bool { model.vertical || Book.languageCode(model.book.language) == "ja" }
    private var ink: Color { Color(uiColor: model.settings.paper.ink) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.18)
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .accessibilityLabel("Back to reading")
                .accessibilityAddTraits(.isButton)
            band
        }
        .ignoresSafeArea()
        .onAppear {
            startPage = model.currentPage
            scrub = Double(model.currentPage)
            lastChapter = map.chapter(forPage: model.currentPage)
        }
    }

    private var band: some View {
        let page = Int(scrub.rounded())
        let chapter = map.chapter(forPage: page)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(chapter.map { map.chapters[$0].title } ?? model.book.title)
                    .font(Typesetter.swiftUIFont(model.settings.face(for: model.book), size: 19, bold: true))
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(japanese ? "\(page + 1) / \(map.pageCount)頁" : "\(page + 1) of \(map.pageCount)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(ink.opacity(0.6))
            }
            scrubber
            if map.chapters.count > 1 { chapterList(current: chapter) }
            if page != startPage {
                Button {
                    jump(to: startPage)
                } label: {
                    Label(japanese ? "\(startPage + 1)頁に戻る" : "Back to page \(startPage + 1)", systemImage: "arrow.uturn.backward")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: model.settings.ribbonColor))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 40)
        .frame(maxWidth: 640)
        .background {
            ZStack {
                Color(uiColor: model.settings.paper.color)
                Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile).opacity(model.settings.paper.isDark ? 0.4 : 1)
            }
            .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.15)).frame(height: 0.5) }
            .shadow(color: .black.opacity(0.25), radius: 18, y: -4)
        }
        .transition(.move(edge: .bottom))
    }

    /// The whole book as one line: chapters as ticks, the page as a bead. A right-to-left book
    /// runs right to left, as its pages do.
    private var scrubber: some View {
        Slider(value: $scrub, in: 0...Double(max(map.pageCount - 1, 1)), step: 1)
            .tint(Color(hex: model.settings.ribbonColor))
            .background {
                GeometryReader { geo in
                    ForEach(map.chapters.indices, id: \.self) { i in
                        Rectangle()
                            .fill(ink.opacity(0.35))
                            .frame(width: 1, height: 10)
                            .position(x: 12 + (geo.size.width - 24) * map.fraction(ofPage: map.chapters[i].page),
                                      y: geo.size.height / 2 + 12)
                    }
                }
            }
            .environment(\.layoutDirection, model.layout.rightToLeft ? .rightToLeft : .leftToRight)
            .onChange(of: scrub) { _, value in
                let page = Int(value.rounded())
                guard page != model.currentPage else { return }
                model.go(to: page)
                let chapter = map.chapter(forPage: page)
                if chapter != lastChapter, model.settings.haptics { UISelectionFeedbackGenerator().selectionChanged() }
                lastChapter = chapter
            }
            .accessibilityLabel("Page")
            .accessibilityValue("\(Int(scrub) + 1) of \(map.pageCount)")
    }

    private func chapterList(current: Int?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(map.chapters.indices, id: \.self) { i in
                        Button {
                            jump(to: map.chapters[i].page)
                            close()
                        } label: {
                            HStack {
                                Text(map.chapters[i].title)
                                    .font(Typesetter.swiftUIFont(model.settings.face(for: model.book), size: 16))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(map.chapters[i].page + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(ink.opacity(0.5))
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 10)
                            .background(i == current ? ink.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
            }
            .frame(maxHeight: 220)
            .onAppear { if let current { proxy.scrollTo(current, anchor: .center) } }
        }
    }

    private func jump(to page: Int) {
        scrub = Double(page)
        model.go(to: page)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) { model.showsNavigator = false }
    }
}
