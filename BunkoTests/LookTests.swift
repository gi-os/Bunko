import Foundation
import Testing
@testable import Bunko

struct LookTests {
    private func shelf(_ count: Int) -> [Book] {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return (0..<count).map { i in
            let japanese = i.isMultiple(of: 2)
            // Every seventh book is a volume of one of three series.
            let title = i % 7 == 0 ? "\(["猫町", "Dune", "Saga"][i / 7 % 3]) Vol. \(i / 21 + 1)" : (japanese ? "本\(i)" : "Book \(i)")
            return Book(id: "book-\(i)", title: title, author: "Author \(i % 11)", fileName: "", format: .txt,
                        language: japanese ? "ja" : "en", rightToLeft: japanese, addedAt: start.addingTimeInterval(Double(i)))
        }
    }

    @Test func noTwoBooksOnTheShelfWearTheSameCover() {
        let books = Look.assign(shelf(300))
        var papers: [String: String] = [:], houses: [String: String] = [:]
        for book in books {
            let look = Look.of(book)
            let owner = book.designKey
            if let other = papers[look.paperSignature] { #expect(other == owner, "paper cover repeated: \(book.title)") }
            if let other = houses[look.houseSignature] { #expect(other == owner, "house cover repeated: \(book.title)") }
            papers[look.paperSignature] = owner
            houses[look.houseSignature] = owner
        }
    }

    @Test func aSeriesWearsOneLook() {
        let books = Look.assign(shelf(300))
        // A series is in one language; this shelf alternates, so compare the English volumes.
        let dune = books.filter { $0.volume?.series == "Dune" && !$0.printsJapanese }
        #expect(dune.count > 1)
        #expect(Set(dune.map(\.look)).count == 1)
        #expect(Set(dune.map { CoverStyle.automatic(for: $0) }.map(\.paper)).count == 1)
    }

    @Test func addingABookChangesNobodyElsesCover() {
        let before = Look.assign(shelf(80))
        var later = Book(id: "new", title: "New", author: "Someone", fileName: "", format: .txt, language: "en",
                         rightToLeft: false, addedAt: Date(timeIntervalSince1970: 1_900_000_000))
        later.look = nil
        let after = Look.assign(before + [later])
        #expect(Array(after.prefix(80)).map(\.look) == before.map(\.look))
        #expect(after.last?.look != nil)
    }

    @Test func aLibraryFromBeforeLooksStillLoads() throws {
        let json = Data(#"[{"id":"x","title":"T","author":"A","fileName":"x.txt","format":"txt","language":"en","rightToLeft":false,"addedAt":0}]"#.utf8)
        let books = try JSONDecoder().decode([Book].self, from: json)
        #expect(books.first?.look == nil)
        #expect(Look.assign(books).first?.look == 0)
    }

    @Test func shopsAndPapersAreTheBooksOwn() {
        let ja = Book(id: "j", title: "こころ", author: "夏目漱石", fileName: "", format: .txt, language: "ja", rightToLeft: true, addedAt: .now)
        let en = Book(id: "e", title: "Emma", author: "Jane Austen", fileName: "", format: .txt, language: "en", rightToLeft: false, addedAt: .now)
        #expect(Look.japaneseShops.contains { $0.stamp == CoverStyle.automatic(for: ja).stamp })
        #expect(Look.englishShops.contains { $0.stamp == CoverStyle.automatic(for: en).stamp })
        #expect(CoverStyle.automatic(for: en).paper != .basil)
        // A book from an OPDS shop wears that shop's stamp.
        #expect(CoverStyle.automatic(for: en, shopStamp: "BASIL BOOKS").stamp == "BASIL BOOKS")
    }
}

struct LookVarietyTests {
    @Test func aSmallShelfNeverRepeatsALayout() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let books = Look.assign((0..<40).map { i in
            Book(id: "v\(i)", title: "Title \(i)", author: "A\(i)", fileName: "", format: .txt, language: "en",
                 rightToLeft: false, addedAt: start.addingTimeInterval(Double(i)))
        })
        let looks = books.map(Look.of)
        // 15 houses × 3 layouts: forty books, forty different layouts.
        #expect(Set(looks.map(\.layoutSignature)).count == 40)
        #expect(Set(looks.map(\.shopPaperSignature)).count == 40)
        // No two books in a row from the same shop.
        #expect(zip(looks, looks.dropFirst()).allSatisfy { $0.shop != $1.shop })
    }
}

struct LookHouseTests {
    @Test func aShelfOfFifteenHasFifteenHousesAndEveryPaper() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let books = Look.assign((0..<15).map { i in
            Book(id: "h\(i)", title: "T\(i)", author: "A\(i)", fileName: "", format: .txt, language: i.isMultiple(of: 2) ? "ja" : "en",
                 rightToLeft: i.isMultiple(of: 2), addedAt: start.addingTimeInterval(Double(i)))
        })
        let looks = books.map(Look.of)
        #expect(Set(looks.map(\.houseKey)).count == 15)
        #expect(Set(looks.prefix(9).map(\.paper)).count == 9)
    }
}

@MainActor struct LibraryLookTests {
    @Test func aBookAddedAgainKeepsItsCover() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bunko-look-\(UUID().uuidString)")
        let library = Library(root: root)
        _ = try library.add(data: Data("One".utf8), fileName: "One.txt")
        let first = try library.add(data: Data("Two".utf8), fileName: "Two.txt")
        _ = try library.add(data: Data("Three".utf8), fileName: "Three.txt")
        let look = try #require(first.look)
        let again = try library.add(data: Data("Two".utf8), fileName: "Two.txt")
        #expect(again.look == look)
        #expect(Set(library.books.compactMap(\.look).map { _ in 1 }).count == 1)
        #expect(library.books.allSatisfy { $0.look != nil })
    }
}
