import SwiftUI

@main
struct BunkoApp: App {
    @State private var library: Library
    @State private var sync = SyncStore.shared

    init() {
        let library = Library()
        library.addSamplesIfNeeded(sync: SyncStore.shared)
        _library = State(initialValue: library)
    }

    var body: some Scene {
        WindowGroup {
            ShelfView()
                .environment(library)
                .environment(sync)
                .tint(Color(hex: "8A3A2E"))
                .onOpenURL { url in
                    // "Open in Bunko" from Files, Safari or the share sheet.
                    _ = try? library.importFile(at: url)
                }
        }
    }
}
