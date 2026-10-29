import Foundation
import Testing
import UIKit
@testable import Bunko

struct EnglishHouseTests {
    @Test func fortyFiveHousesThreeForEachTechnique() {
        let all = EnglishHouse.all
        #expect(all.count == 45)
        #expect(Set(all.map(\.id)).count == 45)
        #expect(Set(all.map(\.name)).count == 45)
        for technique in EnglishHouse.Technique.allCases {
            #expect(all.filter { $0.technique == technique }.map(\.composition).sorted() == [0, 1, 2], "\(technique)")
        }
    }

    @Test func everyMarkIsItsOwnAcrossAllSixtyEnglishHouses() {
        let marks = EnglishHouse.all.map(\.colophon) + House.Imprint.allCases.map(\.englishColophon)
        #expect(Set(marks).count == 60)
        // And no house shares a name with an English edition of a Japanese one.
        #expect(Set(EnglishHouse.all.map(\.name)).isDisjoint(with: House.Imprint.allCases.map(\.englishName)))
    }

    @Test func everyFaceIsOnTheDevice() {
        for face in EnglishHouse.Face.allCases {
            #expect(UIFont(name: face.names.regular, size: 12) != nil, "\(face.names.regular)")
            #expect(UIFont(name: face.names.bold, size: 12) != nil, "\(face.names.bold)")
        }
    }

    private func book(_ i: Int, japanese: Bool) -> Book {
        Book(id: "eh-\(japanese ? "j" : "e")-\(i)", title: "Title \(i)", author: "Author \(i)", fileName: "", format: .txt,
             language: japanese ? "ja" : "en", rightToLeft: japanese,
             addedAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(i)))
    }

    @Test func englishBooksDrawFromSixtyJapaneseFromFifteen() {
        let english = (0..<400).map { Look.of(book($0, japanese: false)) }
        let withEdition = english.filter { $0.edition != nil }.count
        // Forty-five of sixty: about three in four.
        #expect((240...360).contains(withEdition))
        #expect((0..<200).map { Look.of(book($0, japanese: true)) }.allSatisfy { $0.edition == nil })
        #expect(House.of(book(1, japanese: true), edition: EnglishHouse.all[0]).edition == nil)
    }

    @Test func aShelfOfSixtyEnglishBooksHasSixtyHouses() {
        let books = Look.assign((0..<60).map { book($0, japanese: false) })
        #expect(Set(books.map { Look.of($0).houseKey }).count == 60)
    }

    @Test func theChosenEnglishHouseSyncsAndUnknownOnesFallBack() throws {
        var style = CoverStyle(paper: .kraft)
        style.edition = "marbledleaf"
        #expect(try JSONDecoder().decode(CoverStyle.self, from: JSONEncoder().encode(style)).edition == "marbledleaf")
        #expect(try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"kraft","edition":"gone"}"#.utf8)).edition == nil)
        #expect(try JSONDecoder().decode(CoverStyle.self, from: Data(#"{"paper":"kraft"}"#.utf8)).edition == nil)
    }

    @Test func everyHouseHasASpine() {
        for house in EnglishHouse.all {
            let spine = house.spine(colour: "8E2F2A", variant: 1)
            #expect(spine.name == house.name)
            #expect(spine.colophon == house.colophon)
            #expect(spine.bands.allSatisfy { $0.from < $0.to && $0.from >= 0 && $0.to <= 1 })
        }
    }
}
