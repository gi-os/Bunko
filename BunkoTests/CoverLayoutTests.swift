import Foundation
import Testing
@testable import Bunko

struct CoverLayoutTests {
    @Test func shortVerticalTitlesKeepTheUsualSize() {
        let slip = PaperCover.verticalSlip(count: 6, base: 30, height: 480)
        #expect(slip.columns == 1)
        #expect(slip.size == 30)
    }

    @Test func longerVerticalTitlesShrinkToFitWhole() {
        let slip = PaperCover.verticalSlip(count: 20, base: 30, height: 480)
        #expect(slip.columns == 1)
        #expect(slip.size < 30)
        #expect(slip.size * (1.08 * 20 + 0.6) <= 480.001)
    }

    @Test func veryLongVerticalTitlesRunOnIntoASecondColumn() {
        let slip = PaperCover.verticalSlip(count: 40, base: 30, height: 480)
        #expect(slip.columns == 2)
        #expect(slip.size * (1.08 * 20 + 0.6) <= 480.001)
        #expect(slip.size > 30 * 0.62)
    }
}

struct ClosedBookTests {
    @Test func aPhoneHeldUprightIsAllBook() {
        #expect(ClosedBookView.bookSize(on: CGSize(width: 402, height: 874)) == nil)
        // The Duo unfolded upright is already a bunko's shape.
        #expect(ClosedBookView.bookSize(on: CGSize(width: 2007 / 3, height: 2853 / 3)) == nil)
    }

    @Test func aWideScreenGetsABunkoOnTheTable() throws {
        let size = try #require(ClosedBookView.bookSize(on: CGSize(width: 951, height: 669)))
        #expect(abs(size.width / size.height - 105.0 / 148.0) < 0.001)
        #expect(size.height < 669)
    }
}

struct VolumeNumeralTests {
    @Test func volumesInKanji() {
        #expect(Book.Volume.kanji(1) == "一")
        #expect(Book.Volume.kanji(10) == "十")
        #expect(Book.Volume.kanji(12) == "十二")
        #expect(Book.Volume.kanji(23) == "二十三")
        #expect(Book.Volume.kanji(2.5) == "2.5")
    }
}
