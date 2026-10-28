import Foundation
import Testing
@testable import Bunko

struct CoverTests {
    @Test func sealSetsJapaneseInColumnsAndLatinInRows() {
        #expect(CoverStyle.sealLines("文庫堂").lines == ["文庫堂"])
        #expect(CoverStyle.sealLines("文庫堂").vertical)
        #expect(CoverStyle.sealLines("文庫堂 本店").lines == ["文庫堂", "本店"])
        #expect(CoverStyle.sealLines("Bunko").lines == ["BUNKO"])
        #expect(!CoverStyle.sealLines("Bunko").vertical)
        #expect(CoverStyle.sealLines("BASIL BOOKS · LES").lines == ["BASIL", "BOOKS", "LES"])
        #expect(CoverStyle.sealLines("  ").lines.isEmpty)
    }

    @Test func sealSplitsLongNamesEvenly() {
        #expect(CoverStyle.sealLines("紀伊國屋書店新宿本店").lines == ["紀伊國屋書", "店新宿本店"])
        // Never more than three columns of six.
        #expect(CoverStyle.sealLines(String(repeating: "本", count: 30)).lines.map(\.count) == [6, 6, 6])
        // Latin keeps whole words, at most three rows.
        #expect(CoverStyle.sealLines("The Last Bookshop on Main Street").lines == ["THE LAST", "BOOKSHOP ON", "MAIN STREET"])
    }

    @Test func dogEarWaitsUntilABookIsWellRead() {
        #expect(WearOverlay.dogEar(0) == 0)
        #expect(WearOverlay.dogEar(0.39) == 0)
        #expect(WearOverlay.dogEar(0.4) > 0)
        #expect(WearOverlay.dogEar(1) > WearOverlay.dogEar(0.6))
        #expect(WearOverlay.dogEar(5) == WearOverlay.dogEar(1))
    }

    @Test func newPapersAndTheSealSurviveSync() throws {
        var style = CoverStyle(paper: .seigaiha, stamp: "文庫堂")
        style.stampShape = .seal
        let copy = try JSONDecoder().decode(CoverStyle.self, from: JSONEncoder().encode(style))
        #expect(copy == style)
    }

    @Test func aCoverFromANewerCopyStillLoads() throws {
        // A paper or stamp this copy doesn't know falls back rather than failing.
        let json = Data(#"{"paper":"kikko","stamp":"BUNKO","stampShape":"hexagon"}"#.utf8)
        let style = try JSONDecoder().decode(CoverStyle.self, from: json)
        #expect(style.paper == .kraft)
        #expect(style.stampShape == .circle)
    }
}
