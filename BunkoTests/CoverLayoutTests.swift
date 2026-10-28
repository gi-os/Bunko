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
