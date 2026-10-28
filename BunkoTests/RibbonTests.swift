import Foundation
import Testing
@testable import Bunko

struct RibbonTests {
    @Test func theRibbonIsOutUntilLaidIn() throws {
        // Progress saved before the ribbon could be taken out had it laid automatically: it's out now.
        let old = try JSONDecoder().decode(ReadingProgress.self, from: Data(#"{"offset": 120, "ribbon": 100, "fraction": 0.3}"#.utf8))
        #expect(!old.hasRibbon)
        #expect(!ReadingProgress(offset: 0, ribbon: 0, fraction: 0).hasRibbon)
    }

    @Test func aLaidRibbonSurvivesSync() throws {
        var progress = ReadingProgress(offset: 500, ribbon: 420, fraction: 0.4)
        progress.hasRibbon = true
        let copy = try JSONDecoder().decode(ReadingProgress.self, from: JSONEncoder().encode(progress))
        #expect(copy.hasRibbon)
        #expect(copy.ribbon == 420)
    }
}
