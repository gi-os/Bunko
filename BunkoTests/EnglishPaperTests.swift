import Foundation
import Testing
@testable import Bunko

struct EnglishPaperTests {
    @Test func thirtyEnglishPapersOnTopOfTheTen() {
        #expect(CoverStyle.Paper.english.count == 30)
        #expect(CoverStyle.Paper.allCases.count == 40)
        #expect(Set(CoverStyle.Paper.allCases.map(\.label)).count == 40)
        #expect(CoverStyle.Paper.english.allSatisfy { $0.texture == .english })
    }

    @Test func japaneseBooksKeepTheirPapers() {
        // The Japanese draw is unchanged, so no Japanese book's cover moves.
        #expect(Look.papers == [.kraft, .washi, .linen, .newsprint, .indigo, .sakura, .matcha, .seigaiha, .asanoha])
        let japanese = (0..<300).map {
            Look.of(Book(id: "jp\($0)", title: "本\($0)", author: "", fileName: "", format: .txt, language: "ja", rightToLeft: true, addedAt: .now))
        }
        #expect(japanese.allSatisfy { !$0.paper.isEnglish })
    }

    @Test func englishBooksDrawFromThirtyNine() {
        let english = (0..<390).map {
            Look.of(Book(id: "en\($0)", title: "Book \($0)", author: "", fileName: "", format: .txt, language: "en", rightToLeft: false, addedAt: .now))
        }
        let own = english.filter { $0.paper.isEnglish }.count
        // Thirty of thirty-nine: about three in four.
        #expect((240...360).contains(own))
        #expect(Set(english.map(\.paper)).count >= 35)
    }

    @Test func aPaperFromANewerCopyStillLoads() throws {
        let style = try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"tartan"}"#.utf8))
        #expect(style.paper == .tartan)
        let unknown = try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"wallpaper"}"#.utf8))
        #expect(unknown.paper == .kraft)
    }
}
