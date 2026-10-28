import SwiftUI

/// Correct a book's details: title, author, series and volume, language, and which way it reads.
struct BookInfoView: View {
    let book: Book
    @Environment(Library.self) private var library
    @Environment(SyncStore.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var info: BookInfo
    @State private var volume: String

    /// Languages offered by name; anything else is typed as a code.
    static let languages: [(code: String, name: String)] = [
        ("ja", "Japanese 日本語"), ("en", "English"), ("zh", "Chinese 中文"), ("ko", "Korean 한국어"),
        ("fr", "French"), ("de", "German"), ("es", "Spanish"), ("it", "Italian"),
        ("ar", "Arabic العربية"), ("he", "Hebrew עברית"),
    ]

    init(book: Book) {
        self.book = book
        _info = State(initialValue: BookInfo(book))
        _volume = State(initialValue: book.seriesIndex.map(Book.Volume.label) ?? "")
    }

    private var languageChoice: Binding<String> {
        Binding(
            get: {
                let code = Book.languageCode(info.language)
                return Self.languages.contains { $0.code == code } ? code : "other"
            },
            set: { code in
                guard code != "other" else { return }
                info.language = code
                // A new language brings its usual direction; the toggle below can still change it.
                info.rightToLeft = Book.boundOnRight(language: code)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $info.title, axis: .vertical)
                    TextField("Author", text: $info.author)
                }
                Section {
                    TextField("Series", text: Binding(get: { info.series ?? "" }, set: { info.series = $0 }))
                    TextField("Volume", text: $volume)
                        .keyboardType(.decimalPad)
                        .disabled((info.series ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Series")
                } footer: {
                    Text("Books in the same series stand together on the shelf, in order, and share a cover design.")
                }
                Section {
                    Picker("Language", selection: languageChoice) {
                        ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
                        Text("Other").tag("other")
                    }
                    if languageChoice.wrappedValue == "other" {
                        TextField("Language code (e.g. pt, ru)", text: $info.language)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Bound on the right", isOn: $info.rightToLeft)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Bound on the right: pages turn right to left, and Japanese is set in vertical columns.")
                }
                Section {
                    LabeledContent("Format", value: book.format == .epub ? "EPUB" : "Plain text")
                    LabeledContent("Added", value: book.addedAt.formatted(date: .abbreviated, time: .omitted))
                    if let shop = sync.shops.first(where: { $0.id == book.shopID }) {
                        LabeledContent("From", value: shop.name)
                    }
                    if sync.info(for: book) != nil, let original = library.originalInfo(for: book) {
                        Button("Use the book's own details") {
                            info = original
                            volume = original.seriesIndex.map(Book.Volume.label) ?? ""
                        }
                    }
                } footer: {
                    Text("Your changes stay in Bunko and follow you to your other devices; the book's file isn't changed.")
                }
            }
            .navigationTitle("Book info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var edited = info
                        edited.seriesIndex = Double(volume.replacingOccurrences(of: ",", with: "."))
                        withAnimation { library.edit(book, to: edited, sync: sync) }
                        dismiss()
                    }
                }
            }
        }
    }
}
