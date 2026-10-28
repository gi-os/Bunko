import SwiftUI

/// Your book servers. Each one is a bookshop: its books come home in paper with its stamp.
struct ShopsView: View {
    @Environment(SyncStore.self) private var sync
    @State private var adding = false

    var body: some View {
        List {
            ForEach(sync.shops) { shop in
                NavigationLink {
                    ShopBrowserView(shop: shop, url: shop.feedURL, title: shop.name)
                } label: {
                    HStack(spacing: 14) {
                        PaperCover(style: CoverStyle(paper: .kraft, stamp: shop.stamp),
                                   book: Book(id: shop.id.uuidString, title: shop.name, author: "", fileName: "", format: .epub,
                                              language: "", rightToLeft: false, addedAt: .now))
                            .frame(width: 34, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shop.name).font(.headline)
                            Text(shop.feedURL.host() ?? shop.feedURL.absoluteString).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                var shops = sync.shops
                for index in offsets { Keychain.delete(shops[index].id) }
                shops.remove(atOffsets: offsets)
                sync.shops = shops
            }
        }
        .overlay {
            if sync.shops.isEmpty {
                ContentUnavailableView {
                    Label("No bookshops yet", systemImage: "building.columns")
                } description: {
                    Text("Add BasilNet, a Calibre library, Calibre-Web, Kavita or any OPDS catalog.")
                } actions: {
                    Button("Add a bookshop") { adding = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Bookshops")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a bookshop")
            }
        }
        .sheet(isPresented: $adding) { AddShopView() }
    }
}

struct AddShopView: View {
    @Environment(SyncStore.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var name = "BasilNet"
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var stamp = "BASILNET"
    @State private var checking = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address, prompt: Text("basilnet.local:8083/opds"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Calibre and Calibre-Web: the server with /opds. Kavita: the OPDS URL from your user settings (it holds your API key). Komga: /opds/v1.2/catalog.")
                }
                Section("Login (if it has one)") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                Section {
                    TextField("Stamp", text: $stamp).textInputAutocapitalization(.characters)
                } footer: {
                    Text("Books from this shop come wrapped in kraft paper with this stamp.")
                }
                if let problem {
                    Section {
                        Text(problem).foregroundStyle(.red)
                        Button("Save anyway") { save() }
                    }
                }
            }
            .navigationTitle("Add bookshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if checking {
                        ProgressView()
                    } else {
                        Button("Add") { Task { await check() } }
                            .disabled(Bookshop.feedURL(from: address) == nil || name.isEmpty)
                    }
                }
            }
        }
    }

    private func check() async {
        guard let url = Bookshop.feedURL(from: address) else { return }
        checking = true
        defer { checking = false }
        do {
            _ = try await OPDSClient(username: username, password: password).feed(at: url)
            save()
        } catch {
            problem = (error as? LocalizedError)?.errorDescription ?? "Couldn't reach \(url.absoluteString): \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let url = Bookshop.feedURL(from: address) else { return }
        let shop = Bookshop(name: name, feedURL: url, username: username, stamp: stamp.isEmpty ? name.uppercased() : stamp)
        Keychain.setPassword(password, for: shop.id)
        sync.shops = sync.shops + [shop]
        dismiss()
    }
}

/// One page of a bookshop's catalog: shelves to walk into, books to bring home.
struct ShopBrowserView: View {
    let shop: Bookshop
    let url: URL
    let title: String
    @Environment(Library.self) private var library
    @Environment(SyncStore.self) private var sync
    @State private var feed: OPDSFeed?
    @State private var problem: String?
    @State private var downloading: Set<String> = []
    @State private var failed: Set<String> = []
    @State private var loadingMore = false

    var body: some View {
        List {
            if let feed {
                ForEach(feed.entries) { entry in
                    if let navigation = entry.navigation {
                        NavigationLink(entry.title) {
                            ShopBrowserView(shop: shop, url: navigation, title: entry.title)
                        }
                    } else {
                        bookRow(entry)
                    }
                }
                if let next = feed.next {
                    Button(loadingMore ? "Loading…" : "More") { Task { await loadMore(next) } }
                        .disabled(loadingMore)
                }
            }
        }
        .overlay {
            if let problem {
                ContentUnavailableView("Couldn't open \(shop.name)", systemImage: "wifi.exclamationmark", description: Text(problem))
            } else if feed == nil {
                ProgressView()
            }
        }
        .navigationTitle(title)
        .refreshable { await load() }
        .task { if feed == nil { await load() } }
    }

    private func bookRow(_ entry: OPDSFeed.Entry) -> some View {
        let id = Book.stableID(title: entry.title, author: entry.author)
        let owned = library.books.contains { $0.id == id }
        return HStack(spacing: 14) {
            PaperCover(style: CoverStyle(paper: .kraft, stamp: shop.stamp),
                       book: Book(id: id, title: entry.title, author: entry.author, fileName: "", format: .epub,
                                  language: "", rightToLeft: false, addedAt: .now))
                .frame(width: 44, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.headline).lineLimit(2)
                if !entry.author.isEmpty { Text(entry.author).font(.subheadline).foregroundStyle(.secondary) }
                if !entry.summary.isEmpty { Text(entry.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            if owned {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if downloading.contains(entry.id) {
                ProgressView()
            } else if let link = entry.download {
                Button {
                    Task { await download(entry, link: link) }
                } label: {
                    Image(systemName: failed.contains(entry.id) ? "exclamationmark.arrow.circlepath" : "arrow.down.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Download \(entry.title)")
            } else {
                Text("No EPUB").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        do {
            feed = try await OPDSClient(shop: shop).feed(at: url)
            problem = nil
        } catch {
            problem = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadMore(_ next: URL) async {
        loadingMore = true
        defer { loadingMore = false }
        guard let more = try? await OPDSClient(shop: shop).feed(at: next) else { return }
        feed?.entries += more.entries
        feed?.next = more.next
    }

    private func download(_ entry: OPDSFeed.Entry, link: OPDSFeed.Link) async {
        downloading.insert(entry.id)
        failed.remove(entry.id)
        defer { downloading.remove(entry.id) }
        do {
            let data = try await OPDSClient(shop: shop).data(from: link.href)
            let ext = link.type.hasPrefix("text/plain") ? "txt" : "epub"
            let safeTitle = entry.title.replacingOccurrences(of: "/", with: "-")
            let book = try library.add(data: data, fileName: "\(safeTitle).\(ext)", shopID: shop.id)
            if sync.storedCover(for: book) == nil {
                sync.setCover(CoverStyle(paper: .kraft, stamp: shop.stamp), for: book)
            }
        } catch {
            failed.insert(entry.id)
        }
    }
}
