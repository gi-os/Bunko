import SwiftUI

/// Dress a book: pick a paper, ink a stamp, add a title slip, choose its obi, or slide the paper off.
struct CoverEditorView: View {
    let book: Book
    @Environment(SyncStore.self) private var sync
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var style: CoverStyle
    /// Dress every volume of its series alike, and any added later.
    @State private var wholeSeries = true
    /// Opens at the foot, on the obi (the last section): for the screenshots.
    var opensAtObi = false

    init(book: Book, style: CoverStyle, opensAtObi: Bool = false) {
        self.book = book
        self.opensAtObi = opensAtObi
        _style = State(initialValue: style)
    }

    private var tint: Binding<Color> {
        Binding(
            get: { Color(hex: style.baseHex) },
            set: { style.tint = UIColor($0).hex }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CoverView(style: style, book: book, original: library.originalCover(for: book))
                        .aspectRatio(105.0 / 148.0, contentMode: .fit)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                        .animation(.easeInOut(duration: 0.3), value: style)
                        .onTapGesture { style.wrapped.toggle() }

                    Toggle("Paper cover", isOn: $style.wrapped)
                    if let volume = book.volume {
                        Toggle(isOn: $wholeSeries) {
                            Text("Whole series")
                            Text(seriesBooks.count > 1 ? "\(volume.series) · all \(seriesBooks.count) books, and any added later"
                                                       : "\(volume.series) · and any volumes added later")
                        }
                    }

                    if style.wrapped {
                        papers
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stamp").font(.headline)
                            TextField("Stamp", text: $style.stamp)
                                .textInputAutocapitalization(.characters)
                                .padding(10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            Picker("Stamp shape", selection: $style.stampShape) {
                                ForEach(CoverStyle.StampShape.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        Toggle("Title slip", isOn: $style.showsLabel)
                        HStack {
                            ColorPicker("Paper colour", selection: tint, supportsOpacity: false)
                            if style.tint != nil {
                                Button("Reset") { style.tint = nil }.buttonStyle(.bordered)
                            }
                        }
                    }
                    obis
                }
                .padding(20)
            }
            .defaultScrollAnchor(opensAtObi ? .bottom : nil)
            .navigationTitle("Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if book.volume != nil && wholeSeries {
                            sync.setSeriesCover(style, for: book)
                            for volume in seriesBooks { sync.setCover(style, for: volume) }
                        } else {
                            sync.setCover(style, for: book)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    /// The volumes on the shelf from this book's series, itself included.
    private var seriesBooks: [Book] {
        guard book.volume != nil else { return [book] }
        return library.books.filter { $0.designKey == book.designKey }
    }

    /// Every kind of obi on this book, wearing what it would say now (or a sample).
    private var obis: some View {
        let japanese = book.rightToLeft || book.language.hasPrefix("ja")
        let obi = Obi.closed(sync.progress(for: book), japanese: japanese) ?? .sample(japanese: japanese)
        let kinds: [ObiStyle?] = [nil] + ObiStyle.allCases.map(Optional.some)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Obi").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                ForEach(kinds, id: \.self) { kind in
                    Button { style.obi = kind } label: {
                        VStack(spacing: 6) {
                            CoverView(style: dressed(kind), book: book, original: library.originalCover(for: book), obi: obi)
                                .aspectRatio(105.0 / 148.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .stroke(kind == style.obi ? Color.accentColor : .clear, lineWidth: 2.5)
                                    .padding(-3))
                            Text(kind?.label ?? "Auto · \(ObiStyle.automatic(for: book.id).label)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dressed(_ kind: ObiStyle?) -> CoverStyle {
        var dressed = style
        dressed.obi = kind
        return dressed
    }

    private var papers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paper").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 14) {
                ForEach(CoverStyle.Paper.allCases) { paper in
                    Button {
                        let customStamp = style.stamp != style.paper.defaultStamp
                        style.paper = paper
                        style.tint = nil
                        if !customStamp { style.stamp = paper.defaultStamp }
                    } label: {
                        VStack(spacing: 6) {
                            PaperCover(style: CoverStyle(paper: paper), book: book)
                                .aspectRatio(105.0 / 148.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .stroke(paper == style.paper ? Color.accentColor : .clear, lineWidth: 2.5)
                                    .padding(-3))
                            Text(paper.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
