# Bunko

iOS app (SwiftUI) on the gi-os kit. The shared house rules, pipeline and skills come from
gi-os/.github and are loaded at session start by `.claude/hooks/session-start.sh`; the kit itself
is in `.gios/` (read-only here: change it in gi-os/.github).

## This app

- What it is: an e-reader that feels like holding a bunkobon (文庫本). The screen *is* the book:
  full-bleed pages, no chrome, vertical Japanese (縦書き) bound on the right, a two-page spread
  on wide screens (the iPhone Duo unfolded, any iPhone on its side), stacked page edges that show
  how far in you are, a ribbon bookmark (スピン), and bookshop paper covers (書店カバー).
- Gestures, not buttons: pinch the pages together to close the book → its cover fills the screen →
  swipe it away to put it back on the shelf (spread two fingers to reopen). Two-finger tap brings up the chapters and a
  scrubber through the book (a paper band, gone on the next tap). Three-finger tap opens
  settings. Tap the ribbon to go back to it, hold it to move it. Backgrounding (folding the Duo)
  closes the book.
- Code map: `Bunko/App` entry point; `Bunko/Model` books, EPUB/ZIP/HTML/plain-text reading, the
  library; `Bunko/Reader` typesetting (CoreText), pagination, page drawing, the UIPageViewController
  page turner, the reader screen; `Bunko/Covers` paper covers and the cover editor; `Bunko/Shelf`;
  `Bunko/Shops` OPDS bookshops (Calibre, Calibre-Web, Kavita, Komga); `Bunko/Settings`;
  `Bunko/Sync` iCloud key-value sync; `BunkoTests` unit tests (Swift Testing).
- Config: `project.yml` (targets, Info.plist keys, version), `ci/app.env` (pipeline knobs).

## App-specific rules

- Keep logic out of views so `BunkoTests` can test it.
- Never add chrome to the open book (buttons, bars, status bar). New controls go in the settings
  sheet; new actions are gestures.
- Reading position is a character offset (`ReadingProgress.offset`), never a page number: pages
  change with font, size and spread.
- Book details you edit (`BookInfo`, synced as `info.<id>`) are applied over the file's; the
  book keeps its ID and its file is never rewritten.
- Synced types (`ReaderSettings`, `CoverStyle`) decode every field with a default, so an older
  copy from another device still loads. Keep that when adding fields.
- iCloud is the key-value store only (1 MB): small state, never book files. `ICLOUD="true"` in
  ci/app.env turns the capability on.
