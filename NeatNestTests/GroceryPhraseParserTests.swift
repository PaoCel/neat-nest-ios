import XCTest
@testable import NeatNest

final class GroceryPhraseParserTests: XCTestCase {
    private let parser = GroceryPhraseParser()

    func testSplitsASpokenSentenceIntoItems() {
        // È il caso che oggi produceva un articolo solo con dentro tutta la frase.
        let items = parser.parse("due litri di latte, il pane e sei uova")

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.map(\.name), ["latte", "pane", "uova"])
    }

    func testReadsSpelledOutQuantities() {
        let items = parser.parse("due litri di latte")

        XCTAssertEqual(items.first?.quantity, 2)
        XCTAssertEqual(items.first?.unit, "l")
        XCTAssertEqual(items.first?.name, "latte")
    }

    func testReadsNumericQuantities() {
        let items = parser.parse("500 g farina")

        XCTAssertEqual(items.first?.quantity, 500)
        XCTAssertEqual(items.first?.unit, "g")
        XCTAssertEqual(items.first?.name, "farina")
    }

    func testDefaultsToOneWhenNoQuantityIsSaid() {
        let items = parser.parse("pane")

        XCTAssertEqual(items.first?.quantity, 1)
        XCTAssertNil(items.first?.unit)
    }

    func testOneItemPerLine() {
        let items = parser.parse("latte\npane\ndue chili di patate")

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.last?.quantity, 2)
        XCTAssertEqual(items.last?.unit, "kg")
        XCTAssertEqual(items.last?.name, "patate")
    }

    func testStripsArticlesAndVerbs() {
        XCTAssertEqual(parser.parse("compra il pane").first?.name, "pane")
        XCTAssertEqual(parser.parse("della passata di pomodoro").first?.name, "passata di pomodoro")
    }

    func testKeepsMultiWordProductNames() {
        let items = parser.parse("latte senza lattosio, pomodori pelati")

        XCTAssertEqual(items.map(\.name), ["latte senza lattosio", "pomodori pelati"])
    }

    func testHandlesHalfQuantities() {
        let items = parser.parse("mezzo chilo di zucchine")

        XCTAssertEqual(items.first?.quantity, 0.5)
        XCTAssertEqual(items.first?.unit, "kg")
    }

    func testIgnoresEmptyAndTooShortSegments() {
        let items = parser.parse("latte, , a, pane")

        XCTAssertEqual(items.map(\.name), ["latte", "pane"])
    }

    func testDoesNotSplitWordsContainingE() {
        // "pere" non deve diventare "p" + "re".
        let items = parser.parse("pere e mele")

        XCTAssertEqual(items.map(\.name), ["pere", "mele"])
    }

    func testEmptyTextProducesNothing() {
        XCTAssertTrue(parser.parse("").isEmpty)
        XCTAssertTrue(parser.parse("   ").isEmpty)
    }

    func testDraftCarriesQuantityAndUnit() {
        let draft = parser.parse("tre bottiglie di acqua").first?.draft

        XCTAssertEqual(draft?.quantity, 3)
        XCTAssertEqual(draft?.unit, "bottiglia")
        XCTAssertEqual(draft?.rawInputText, "acqua")
    }
}
