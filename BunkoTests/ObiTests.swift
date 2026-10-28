import Foundation
import Testing
@testable import Bunko

struct ObiTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ day: Int, hour: Int = 21) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func todaysPagesResetOnANewDay() {
        var p = ReadingProgress(offset: 0, ribbon: 0, fraction: 0)
        p.recordTurn(pages: 2, now: date(27), calendar: calendar)
        p.recordTurn(pages: 1, now: date(27, hour: 23), calendar: calendar)
        #expect(p.pagesToday(now: date(27, hour: 23), calendar: calendar) == 3)
        #expect(p.pagesToday(now: date(28, hour: 8), calendar: calendar) == 0)
        p.recordTurn(pages: 4, now: date(28), calendar: calendar)
        #expect(p.pagesToday(now: date(28), calendar: calendar) == 4)
        #expect(p.pagesRead == 7)
        #expect(p.startedAt == date(27))
    }

    @Test func wearGrowsWithPagesRead() {
        var p = ReadingProgress(offset: 0, ribbon: 0, fraction: 0)
        #expect(p.wear == 0)
        p.pagesRead = 300
        #expect(p.wear == 0.5)
        p.pagesRead = 5000
        #expect(p.wear == 1)
    }

    @Test func finishedObiCarriesTheDateAndDays() {
        var p = ReadingProgress(offset: 0, ribbon: 0, fraction: 1)
        p.startedAt = date(20)
        p.finishedAt = date(28)
        let done = Obi.finished(p, japanese: true, calendar: calendar)
        #expect(done?.headline == "読了")
        #expect(done?.detail == "2026.10.28・9日間")
        #expect(done?.finished == true)
        #expect(done?.days == 9)
        #expect(Obi.finished(p, japanese: false, calendar: calendar)?.detail == "2026.10.28 · in 9 days")
        p.startedAt = date(28, hour: 9)
        #expect(Obi.finished(p, japanese: false, calendar: calendar)?.detail == "2026.10.28 · in a day")
    }

    @Test func closedObiShowsTodayOrNothing() {
        #expect(Obi.closed(nil, japanese: true) == nil)
        var p = ReadingProgress(offset: 0, ribbon: 0, fraction: 0)
        #expect(Obi.closed(p, japanese: true, now: date(28), calendar: calendar) == nil)
        p.recordTurn(pages: 34, now: date(28), calendar: calendar)
        p.fraction = 0.42
        let today = Obi.closed(p, japanese: true, now: date(28), calendar: calendar)
        #expect(today?.headline == "今日 34ページ")
        #expect(today?.detail == "全体の42%")
        #expect(today?.fraction == 0.42)
        #expect(today?.today == 34)
        let later = Obi.closed(p, japanese: false, now: date(29), calendar: calendar)
        #expect(later?.headline == "Pick up where you left off")
        #expect(later?.detail == "42% through")
        #expect(later?.today == 0)
    }

    @Test func obiSetsTheNumberApart() {
        #expect(Obi.runs("今日 34ページ").map(\.text) == ["今日 ", "34", "ページ"])
        #expect(Obi.runs("今日 34ページ").map(\.number) == [false, true, false])
        #expect(Obi.runs("1 page today").map(\.text) == ["1", " page today"])
        #expect(Obi.runs("読了").map(\.number) == [false])
        #expect(Obi.runs("十日").map(\.number) == [false])
    }

    @Test func olderProgressStillDecodes() throws {
        let p = try JSONDecoder().decode(ReadingProgress.self, from: Data(#"{"offset": 120, "ribbon": 100, "fraction": 0.3}"#.utf8))
        #expect(p.offset == 120)
        #expect(p.pagesRead == 0)
        #expect(p.finishedAt == nil)
    }

    @Test func westernBooksGetTheWesternTypeface() {
        let settings = ReaderSettings()
        let alice = Book(id: "a", title: "Alice", author: "", fileName: "", format: .txt, language: "en", rightToLeft: false, addedAt: .now)
        let neko = Book(id: "n", title: "猫", author: "", fileName: "", format: .txt, language: "ja", rightToLeft: true, addedAt: .now)
        #expect(settings.face(for: alice) == .serif)
        #expect(settings.face(for: neko) == .mincho)
    }
}

struct StampTests {
    @Test func longStampsSplitNearTheMiddle() {
        #expect(PaperCover.stampLines("Bunko") == ["BUNKO"])
        #expect(PaperCover.stampLines("BASIL BOOKS · LES") == ["BASIL BOOKS", "LES"])
        #expect(PaperCover.stampLines("Kinokuniya Shinjuku") == ["KINOKUNIYA", "SHINJUKU"])
    }
}
