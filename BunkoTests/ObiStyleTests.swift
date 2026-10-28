import Foundation
import Testing
@testable import Bunko

struct ObiStyleTests {
    private let reading: Obi = {
        var obi = Obi(headline: "今日 34ページ", detail: "全体の42%", fraction: 0.42)
        obi.pages = 260
        obi.today = 34
        return obi
    }()

    private let done: Obi = {
        var obi = Obi(headline: "読了", detail: "2026.10.26・9日間", finished: true)
        obi.pages = 600
        obi.days = 9
        obi.date = "2026.10.26"
        return obi
    }()

    @Test func milestoneCountsPagesLikeAPrintRun() {
        let copy = reading.copy(.milestone, japanese: true, season: .autumn)
        #expect(copy.headline == "累計260ページ突破!")
        #expect(copy.detail == "今日 34ページ・全体の42%")
        #expect(copy.badge == "42%")
        #expect(done.copy(.milestone, japanese: true, season: .autumn).headline == "全600ページ読破!")
        // Progress from before pages were counted keeps the plain words.
        var old = reading
        old.pages = 0
        #expect(old.copy(.milestone, japanese: true, season: .autumn).headline == "今日 34ページ")
    }

    @Test func quoteIsSignedByTheReader() {
        let ja = done.copy(.quote, japanese: true, season: .autumn)
        #expect(ja.headline == "「9日間で読み終えた。」")
        #expect(ja.detail == "—— 2026.10.26のわたし")
        #expect(reading.copy(.quote, japanese: false, season: .autumn).headline == "“34 pages today.”")
        var oneDay = done
        oneDay.days = 1
        #expect(oneDay.copy(.quote, japanese: false, season: .autumn).headline == "“Read it in a day.”")
    }

    @Test func awardAndFairWordings() {
        #expect(done.copy(.award, japanese: true, season: .autumn).headline == "祝・読了")
        #expect(reading.copy(.award, japanese: true, season: .autumn).badge == "42%")
        #expect(reading.copy(.fair, japanese: true, season: .autumn).label == "読書の秋")
        #expect(reading.copy(.fair, japanese: false, season: .summer).label == "Summer Reads")
        #expect(done.copy(.award, japanese: false, season: .autumn).headline == "Read cover to cover")
        #expect(reading.copy(.classic, japanese: true, season: .autumn) == ObiCopy(headline: "今日 34ページ", detail: "全体の42%"))
    }

    @Test func seasonsFollowTheMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        func month(_ m: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: m, day: 15))! }
        #expect(Season.of(month(1), calendar: calendar) == .winter)
        #expect(Season.of(month(4), calendar: calendar) == .spring)
        #expect(Season.of(month(7), calendar: calendar) == .summer)
        #expect(Season.of(month(10), calendar: calendar) == .autumn)
        #expect(Season.of(month(12), calendar: calendar) == .winter)
    }

    @Test func eachBookKeepsItsObiAndTheShelfVaries() {
        #expect(ObiStyle.automatic(for: "neko") == ObiStyle.automatic(for: "neko"))
        let kinds = Set((0..<200).map { ObiStyle.automatic(for: "book-\($0)") })
        #expect(kinds.count == ObiStyle.allCases.count)
    }

    @Test func chosenObiSurvivesSyncAndOldCopiesStillLoad() throws {
        var style = CoverStyle(paper: .washi)
        style.obi = .noir
        #expect(try JSONDecoder().decode(CoverStyle.self, from: JSONEncoder().encode(style)).obi == .noir)
        let old = try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"washi"}"#.utf8))
        #expect(old.obi == nil)
        let newer = try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"washi","obi":"hologram"}"#.utf8))
        #expect(newer.obi == nil)
        #expect(newer.paper == .washi)
    }
}
