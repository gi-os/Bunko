import AppIntents

/// "Read instead": opens the book you're reading, on its cover. Made for a Shortcuts automation
/// (When Instagram is opened → Read instead), so reaching for one app hands you the book.
struct ReadInsteadIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Instead"
    static var description = IntentDescription("Opens the book you're reading, on its cover.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Opener.shared.openCurrentBook()
        return .result()
    }
}

struct BunkoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ReadInsteadIntent(),
                    phrases: ["Read instead with \(.applicationName)", "Open my book in \(.applicationName)"],
                    shortTitle: "Read Instead",
                    systemImageName: "book.closed")
    }
}
