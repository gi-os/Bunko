import SwiftUI

/// Reader settings: from the shelf, or with a three-finger tap on a page (then it also has the
/// book's contents, and every change shows on the page behind as you make it).
struct SettingsView: View {
    var reader: ReaderModel?
    @Environment(SyncStore.self) private var sync
    @Environment(\.dismiss) private var dismiss

    private static let ribbons = ["A8322D", "1F3A5F", "2E5E3A", "C9A13B", "6B3E75", "222222"]

    private var settings: Binding<ReaderSettings> {
        Binding(get: { sync.settings }, set: { sync.settings = $0 })
    }

    var body: some View {
        @Bindable var sync = sync
        NavigationStack {
            Form {
                if let reader, let typeset = reader.typeset, typeset.chapterTitles.contains(where: { !$0.isEmpty }) {
                    Section("Contents") {
                        ForEach(Array(typeset.chapterTitles.enumerated()), id: \.offset) { index, title in
                            if !title.isEmpty {
                                Button {
                                    reader.go(toOffset: typeset.chapterStarts[index])
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(title).foregroundStyle(.primary)
                                        Spacer()
                                        if typeset.chapter(at: reader.currentOffset) == index {
                                            Image(systemName: "bookmark.fill").foregroundStyle(Color(hex: sync.settings.ribbonColor))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Type") {
                    Picker("Japanese", selection: settings.typeface) {
                        ForEach(ReaderSettings.Typeface.allCases) { face in
                            Text(face.label).font(Typesetter.swiftUIFont(face, size: 17)).tag(face)
                        }
                    }
                    Picker("Western", selection: settings.westernTypeface) {
                        ForEach(ReaderSettings.Typeface.allCases) { face in
                            Text(face.label).font(Typesetter.swiftUIFont(face, size: 17)).tag(face)
                        }
                    }
                    LabeledContent("Size") {
                        Slider(value: settings.fontSize, in: 12...28, step: 1) { Text("Size") }
                            minimumValueLabel: { Text("あ").font(.caption) }
                            maximumValueLabel: { Text("あ").font(.title3) }
                    }
                    LabeledContent("Line spacing") {
                        Slider(value: settings.lineSpacing, in: 0.2...1.4) { Text("Line spacing") }
                    }
                    Picker("Writing", selection: settings.direction) {
                        ForEach(ReaderSettings.Direction.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Page") {
                    Picker("Paper", selection: settings.paper) {
                        ForEach(ReaderSettings.Paper.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Turning", selection: settings.turn) {
                        ForEach(ReaderSettings.Turn.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Two-page spread", selection: settings.spread) {
                        ForEach(ReaderSettings.Spread.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Page edges", isOn: settings.showsPageEdges)
                    Toggle("Running head", isOn: settings.showsHeader)
                    Toggle("Haptics", isOn: settings.haptics)
                }

                Section {
                    HStack(spacing: 14) {
                        ForEach(Self.ribbons, id: \.self) { hex in
                            Button {
                                sync.settings.ribbonColor = hex
                            } label: {
                                RibbonShape()
                                    .fill(Color(hex: hex))
                                    .frame(width: 12, height: 40)
                                    .padding(4)
                                    .overlay(alignment: .bottom) {
                                        if sync.settings.ribbonColor == hex {
                                            Circle().fill(.primary).frame(width: 5, height: 5).offset(y: 6)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Ribbon")
                } footer: {
                    Text("Tap the ribbon to go back to it; hold it to move it to the page you're on. Closing the book lays it where you stopped.")
                }

                Section {
                    Toggle("iCloud sync", isOn: $sync.iCloudEnabled)
                } footer: {
                    Text("Reading position, ribbons, covers, these settings and your bookshops follow you to your other devices. Books themselves download again from their bookshop.")
                }

                if reader == nil {
                    Section {
                        NavigationLink("Bookshops") { ShopsView() }
                    }
                }

                Section {
                    Text("Three fingers tap a page for these settings. Pinch the pages together to close the book; swipe the cover away to put it back on the shelf.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(reader?.book.title ?? "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
