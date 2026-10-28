import SwiftUI
import UniformTypeIdentifiers

/// Your books, in their paper covers. Tap to read; hold for the cover and more.
struct ShelfView: View {
    @Environment(Library.self) private var library
    @Environment(SyncStore.self) private var sync
    @State private var reading: ReaderModel?
    @State private var dressing: Book?
    @State private var editingInfo: Book?
    @State private var importing = false
    @State private var showsSettings = false
    @State private var showsShops = false
    @State private var problem: String?
    @State private var routed = false
    @State private var opener = Opener.shared
    /// Spines out, as on a real shelf, or covers face out.
    @AppStorage("bunko.shelf.spines") private var spines = false

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 20, alignment: .bottom)]

    var body: some View {
        NavigationStack {
            Group {
                if spines {
                    SpineShelfView(books: ShelfOrder.arrange(library.books), spine: spine(for:), open: { open($0) },
                                   menu: { AnyView(menu(for: $0)) })
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(ShelfOrder.arrange(library.books)) { book in
                                ShelfBook(book: book, cover: sync.cover(for: book), original: library.originalCover(for: book),
                                          progress: sync.progress(for: book))
                                    .animation(.easeInOut(duration: 0.3), value: sync.cover(for: book))
                                    .onTapGesture { open(book) }
                                    .contextMenu { menu(for: book) }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                    }
                }
            }
            .background(ShelfBackground())
            .overlay {
                if library.books.isEmpty {
                    ContentUnavailableView {
                        Label("An empty shelf", systemImage: "books.vertical")
                    } description: {
                        Text("Add EPUB or text files, or bring books home from a bookshop.")
                    } actions: {
                        Button("Add books") { importing = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Bunko")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showsShops = true } label: { Image(systemName: "building.columns") }
                        .accessibilityLabel("Bookshops")
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add books")
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showsSettings = true } label: { Image(systemName: "textformat.size") }
                        .accessibilityLabel("Settings")
                    Button { withAnimation(.easeInOut(duration: 0.3)) { spines.toggle() } } label: {
                        Image(systemName: spines ? "square.grid.2x2" : "books.vertical")
                    }
                    .accessibilityLabel(spines ? "Show covers" : "Show spines")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.epub, .plainText], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        do { try library.importFile(at: url) } catch { problem = error.localizedDescription }
                    }
                case .failure(let error):
                    problem = error.localizedDescription
                }
            }
            .alert("Couldn't add that book", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(problem ?? "")
            }
            .sheet(item: $dressing) { book in
                CoverEditorView(book: book, style: sync.cover(for: book),
                                opensAt: UserDefaults.standard.string(forKey: "gios-screen").flatMap(CoverEditorView.Section.init(rawValue:)))
            }
            .sheet(item: $editingInfo) { book in BookInfoView(book: book) }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .sheet(isPresented: $showsShops) { NavigationStack { ShopsView() } }
            .fullScreenCover(item: $reading) { model in
                ReaderView(model: model)
            }
            .onAppear(perform: routeForScreenshots)
            .onChange(of: opener.request, initial: true) { _, id in pickUp(id) }
            // Book details corrected on another device.
            .onChange(of: sync.revision, initial: true) { library.applyEdits(from: sync) }
        }
    }

    /// The widget or "Read instead" asked for a book: pick it up on its cover, unless it's
    /// already in your hands.
    private func pickUp(_ id: String?) {
        guard let id else { return }
        opener.request = nil
        guard reading?.book.id != id, let book = library.books.first(where: { $0.id == id }) else { return }
        open(book)
    }

    /// A book's spine, as thick as its file suggests.
    private func spine(for book: Book) -> BookSpine {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: library.fileURL(for: book).path)[.size] as? Int) ?? 0
        let japanese = Book.languageCode(book.language) == "ja"
        let characters = SpineShelf.characters(bytes: bytes, format: book.format, japanese: japanese)
        return BookSpine(book: book, style: sync.cover(for: book), original: library.originalCover(for: book),
                         width: SpineShelf.width(characters: characters, japanese: japanese, id: book.id))
    }

    /// A book opens on its cover, the way you pick one up.
    private func open(_ book: Book, closed: Bool = true) {
        reading = ReaderModel(book: book, library: library, sync: sync, startClosed: closed)
    }

    @ViewBuilder
    private func menu(for book: Book) -> some View {
        Button { open(book) } label: { Label("Read", systemImage: "book") }
        Button { dressing = book } label: { Label("Change cover", systemImage: "paintbrush") }
        Button { editingInfo = book } label: { Label("Edit info", systemImage: "pencil") }
        let cover = sync.cover(for: book)
        Button {
            var style = cover
            style.wrapped.toggle()
            withAnimation { sync.setCover(style, for: book) }
        } label: {
            Label(cover.wrapped ? "Take off the paper" : "Wrap in paper",
                  systemImage: cover.wrapped ? "rectangle.portrait.on.rectangle.portrait.slash" : "rectangle.portrait.on.rectangle.portrait")
        }
        Divider()
        Button(role: .destructive) { library.remove(book) } label: { Label("Remove from shelf", systemImage: "trash") }
    }

    /// CI screenshots launch with -gios-screen <name> (ci/app.env SCREENS).
    private func routeForScreenshots() {
        guard !routed, let screen = UserDefaults.standard.string(forKey: "gios-screen") else { return }
        routed = true
        if screen == "shelf" || screen == "spines" { seedSeriesForScreenshots() }
        spines = screen == "spines"
        // On the spine shelf, the series stands in its publisher's house dress, one design for all.
        if spines {
            for book in library.books where book.volume != nil {
                var style = sync.cover(for: book)
                style.wrapped = false
                sync.setCover(style, for: book)
            }
        }
        seedReadingForScreenshots()
        dressForScreenshots()
        let japanese = library.books.first { $0.rightToLeft && $0.volume == nil } ?? library.books.first
        let english = library.books.first { !$0.rightToLeft && $0.volume == nil }
        switch screen {
        case "reader": if let japanese { open(japanese, closed: false) }
        case "closed": if let japanese { open(japanese, closed: true) }
        case "reader-en": if let english { open(english, closed: false) }
        case "closed-en": if let english { open(english, closed: true) }
        case "cover": dressing = japanese
        case "obi", "houses": dressing = japanese
        case "info": editingInfo = japanese
        case "navigator":
            if let japanese {
                open(japanese, closed: false)
                reading?.showsNavigator = true
            }
        case "settings": showsSettings = true
        case "shops": showsShops = true
        default: break
        }
    }

    /// Screenshots show books that have been read: the Japanese sample half-way through with some
    /// pages today (the closed book's obi, a little wear), the other finished (読了 on the shelf).
    private func seedReadingForScreenshots() {
        let day: TimeInterval = 86_400
        for book in library.books where sync.progress(for: book) == nil && book.volume == nil {
            var progress = ReadingProgress(offset: 0, ribbon: 0, fraction: book.rightToLeft ? 0.42 : 1)
            if book.rightToLeft {
                progress.startedAt = Date.now - 5 * day
                progress.recordTurn(pages: 34)
                progress.pagesRead = 260
            } else {
                progress.startedAt = Date.now - 9 * day
                progress.finishedAt = Date.now - day
                progress.pagesRead = 600
            }
            sync.setProgress(progress, for: book)
        }
    }

    /// The shelf's screenshot has a series, added out of order, standing together in order.
    private func seedSeriesForScreenshots() {
        let text = "猫町の通りを歩いていると、どの窓にも猫がいた。"
        for volume in ["猫町 第2巻", "猫町 第3巻", "猫町 第1巻"] where !library.books.contains(where: { $0.title == volume }) {
            _ = try? library.add(data: Data(text.utf8), fileName: volume + ".txt")
        }
    }

    /// Screenshots show the printed papers and the seal on the Japanese sample (waves, a
    /// bookshop's 朱印) and the others out of their paper, in their publisher's house cover.
    private func dressForScreenshots() {
        for book in library.books where book.volume == nil {
            var style = CoverStyle(paper: book.rightToLeft ? .seigaiha : .asanoha, stamp: book.rightToLeft ? "文庫堂" : nil)
            if book.rightToLeft { style.stampShape = .seal } else { style.wrapped = false }
            sync.setCover(style, for: book)
        }
    }
}

extension ReaderModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

/// One book standing on the shelf: its cover, its depth, a shadow, and how far in you are.
struct ShelfBook: View {
    let book: Book
    let cover: CoverStyle
    let original: UIImage?
    let progress: ReadingProgress?

    var body: some View {
        VStack(spacing: 8) {
            // Finished books wear their obi on the shelf.
            CoverView(style: cover, book: book, original: original, wear: progress?.wear ?? 0,
                      obi: Obi.finished(progress, japanese: book.rightToLeft || book.language.hasPrefix("ja")))
                .aspectRatio(105.0 / 148.0, contentMode: .fit)
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: book.rightToLeft ? 3 : 1, bottomLeading: book.rightToLeft ? 3 : 1,
                    bottomTrailing: book.rightToLeft ? 1 : 3, topTrailing: book.rightToLeft ? 1 : 3)))
                .bookDepth(spineOnRight: book.rightToLeft, depth: 5)
                .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 5)
            if let progress, progress.fraction > 0 {
                Text("\(Int(progress.fraction * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(book.title)
        .accessibilityAddTraits(.isButton)
    }
}
