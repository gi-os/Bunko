import SwiftUI

@main
struct BunkoApp: App {
    @State private var library: Library
    @State private var sync = SyncStore.shared
    @Environment(\.scenePhase) private var scenePhase

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
                    // The widget (bunko://book/<id>), or "Open in Bunko" from Files, Safari or the share sheet.
                    if !Opener.shared.open(url) { _ = try? library.importFile(at: url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget only shows while the app is away: bring its cover up to date on the way out.
            if phase == .background { WidgetSnapshot.update(library: library, sync: sync) }
        }
    }
}
