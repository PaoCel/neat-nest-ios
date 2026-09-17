import XCTest
@testable import NeatNest

final class PantryQuantityTests: XCTestCase {
    func testAddingConvertsBetweenUnitsOfTheSameFamily() {
        let grams = PantryQuantity(value: 500, unit: .gram)
        let kilos = PantryQuantity(value: 1, unit: .kilogram)

        let sum = grams.adding(kilos)

        XCTAssertEqual(sum?.value, 1500)
        XCTAssertEqual(sum?.unit, .gram, "La somma resta nell'unità di chi la riceve")
    }

    func testAddingRefusesDifferentFamilies() {
        let grams = PantryQuantity(value: 100, unit: .gram)
        let millilitres = PantryQuantity(value: 100, unit: .milliliter)

        XCTAssertNil(grams.adding(millilitres))
    }

    func testPacksDoNotMergeWithLoosePieces() {
        // Due confezioni diverse non sono sommabili in modo sensato: 1 confezione
        // di sale + 3 pezzi non fa 4 di niente.
        let packs = PantryQuantity(value: 1, unit: .pack)
        let pieces = PantryQuantity(value: 3, unit: .piece)

        XCTAssertNil(packs.adding(pieces))
        XCTAssertEqual(packs.adding(PantryQuantity(value: 2, unit: .pack))?.value, 3)
    }

    func testSubtractingNeverGoesBelowZero() {
        let have = PantryQuantity(value: 200, unit: .gram)
        let used = PantryQuantity(value: 500, unit: .gram)

        XCTAssertEqual(have.subtracting(used)?.value, 0)
    }

    func testCoversComparesAcrossUnits() {
        let have = PantryQuantity(value: 1, unit: .liter)
        XCTAssertTrue(have.covers(PantryQuantity(value: 750, unit: .milliliter)))
        XCTAssertFalse(have.covers(PantryQuantity(value: 1500, unit: .milliliter)))
    }

    func testCoversRefusesIncompatibleFamilies() {
        let have = PantryQuantity(value: 1000, unit: .gram)
        XCTAssertFalse(have.covers(PantryQuantity(value: 1, unit: .liter)))
    }

    func testFormattedUsesLocaleUnits() {
        let quantity = PantryQuantity(value: 500, unit: .gram)

        let italian = quantity.formatted(locale: Locale(identifier: "it_IT"))
        let american = quantity.formatted(locale: Locale(identifier: "en_US"))

        XCTAssertTrue(italian.contains("g"), "In Italia restano grammi: \(italian)")
        XCTAssertNotEqual(italian, american, "In US la misura va convertita, non ristampata: \(american)")
    }
}
