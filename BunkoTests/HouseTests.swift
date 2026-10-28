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

    @Test func anAuthorKeepsTheirColourAcrossBooks() {
        let a = House.of(book("こころ", by: "夏目漱石", rtl: true))
        let b = House.of(book("坊っちゃん", by: "夏目漱石", rtl: true))
        #expect(a.colour == b.colour)
        // The author's number in the shelf code is theirs too.
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
}
