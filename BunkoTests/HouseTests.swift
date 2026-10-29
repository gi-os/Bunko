import Foundation
import Testing
import UIKit
@testable import Bunko

struct HouseTests {
    private func book(_ title: String, by author: String, rtl: Bool = false) -> Book {
        Book(id: Book.stableID(title: title, author: author), title: title, author: author, fileName: "", format: .txt,
             language: rtl ? "ja" : "en", rightToLeft: rtl, addedAt: .now)
    }

    @Test func shelfCodeStartsWithTheAuthorsInitial() {
        #expect(House.initial(of: "夏目漱石") == "な")
        #expect(House.initial(of: "Lewis Carroll") == "C")
        #expect(House.of(book("こころ", by: "夏目漱石", rtl: true)).shelfCode.hasPrefix("な "))
    }

    @Test func anAuthorKeepsTheirNumberAcrossBooks() {
        let a = House.of(book("こころ", by: "夏目漱石", rtl: true))
        let b = House.of(book("坊っちゃん", by: "夏目漱石", rtl: true))
        // The author's number in the shelf code is theirs, whatever each book looks like.
        #expect(a.shelfCode.split(separator: " ")[1] == b.shelfCode.split(separator: " ")[1])
    }

    @Test func theShelfIsVaried() {
        let imprints = (0..<100).map { House.of(book("Book \($0)", by: "Author \($0)")).imprint }
        #expect(Set(imprints.map(\.name)).count == House.Imprint.allCases.count)
        let prices = (0..<100).map { House.of(book("Book \($0)", by: "A")).price }
        #expect(prices.allSatisfy { (400...890).contains($0) && $0 % 10 == 0 })
    }

    @Test func everyHouseMarkExists() {
        for imprint in House.Imprint.allCases {
            #expect(UIImage(systemName: imprint.mark) != nil, "\(imprint.mark)")
        }
    }

    @Test func fifteenHousesEachWithItsOwnMarks() {
        let houses = House.Imprint.allCases
        #expect(houses.count == 15)
        #expect(Set(houses.map(\.name)).count == 15)
        #expect(Set(houses.map(\.colophon)).count == 15)
        #expect(houses.allSatisfy { $0.colophon.count == 1 && !$0.technique.isEmpty })
    }

    @Test func aChosenHouseOverridesThePick() {
        let b = book("こころ", by: "夏目漱石", rtl: true)
        #expect(House.of(b, imprint: .kinu).imprint == .kinu)
        // The colour and shelf code stay the author's.
        #expect(House.of(b, imprint: .kinu).colour == House.of(b).colour)
        #expect(House.of(b, imprint: .kinu).shelfCode == House.of(b).shelfCode)
    }

    @Test func theChosenHouseSyncsAndOldCopiesStillLoad() throws {
        var style = CoverStyle(paper: .kraft)
        style.house = .aizome
        #expect(try JSONDecoder().decode(CoverStyle.self, from: JSONEncoder().encode(style)).house == .aizome)
        #expect(try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"kraft"}"#.utf8)).house == nil)
        #expect(try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"kraft","house":"marbled"}"#.utf8)).house == nil)
    }

    @Test func englishEditionsNameThemselvesInEnglish() {
        let houses = House.Imprint.allCases
        #expect(Set(houses.map(\.englishName)).count == 15)
        // Each English mark is its own, so the ring tells the houses apart on a spine.
        #expect(Set(houses.map(\.englishColophon)).count == 15)
        #expect(House.Imprint.namari.colophon(english: true) == "&")
        #expect(House.Imprint.shirasagi.name(english: true) == "Egret Books")
        #expect(House.Imprint.shirasagi.name(english: false) == "白鷺文庫")
    }

    @Test func aBookPrintsInItsOwnLanguage() {
        #expect(book("こころ", by: "夏目漱石", rtl: true).printsJapanese)
        #expect(!book("Alice", by: "Lewis Carroll").printsJapanese)
        let arabic = Book(id: "a", title: "ألف ليلة وليلة", author: "", fileName: "", format: .txt, language: "ar", rightToLeft: true, addedAt: .now)
        #expect(!arabic.printsJapanese)
        #expect(!arabic.setVertically)
        let untagged = Book(id: "u", title: "吾輩は猫である", author: "", fileName: "", format: .txt, language: "", rightToLeft: true, addedAt: .now)
        #expect(untagged.printsJapanese)
    }
}
