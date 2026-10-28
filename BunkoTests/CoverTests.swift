import Foundation
import Testing
@testable import Bunko

struct CoverTests {
    @Test func sealSetsShortWordsInTheirOwnColumns() {
        #expect(CoverStyle.sealColumns("Bunko") == ["BUNKO"])
        #expect(CoverStyle.sealColumns("BASIL BOOKS · LES") == ["BASIL", "BOOKS", "LES"])
        #expect(CoverStyle.sealColumns("紀伊國屋書店") == ["紀伊國屋書店"])
        #expect(CoverStyle.sealColumns("  ").isEmpty)
    }

    @Test func sealSplitsLongNamesEvenly() {
        #expect(CoverStyle.sealColumns("Kinokuniya") == ["KINOK", "UNIYA"])
        #expect(CoverStyle.sealColumns("Kinokuniya Shinjuku") == ["KINOKU", "NIYASH", "INJUKU"])
        // Never more than three columns of six.
        #expect(CoverStyle.sealColumns(String(repeating: "A", count: 30)).map(\.count) == [6, 6, 6])
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
