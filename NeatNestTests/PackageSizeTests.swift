import XCTest
@testable import NeatNest

final class PackageSizeTests: XCTestCase {
    func testReadsSimpleWeights() throws {
        let size = try XCTUnwrap(PackageSizeParser.parse("RICOTTA 250G"))

        XCTAssertEqual(size.unitQuantity.value, 250)
        XCTAssertEqual(size.unitQuantity.unit, .gram)
        XCTAssertEqual(size.packCount, 1)
    }

    func testReadsVolumes() throws {
        XCTAssertEqual(try XCTUnwrap(PackageSizeParser.parse("LATTE ARBOREA 1L")).totalQuantity.unit, .liter)
        XCTAssertEqual(try XCTUnwrap(PackageSizeParser.parse("ACQUA 1,5 LT")).totalQuantity.value, 1.5)
        XCTAssertEqual(try XCTUnwrap(PackageSizeParser.parse("PANNA 500ML")).totalQuantity.value, 500)
    }

    func testConvertsCentilitres() throws {
        // I centilitri esistono solo sulle etichette: dentro si lavora in ml.
        let size = try XCTUnwrap(PackageSizeParser.parse("BIRRA 33CL"))

        XCTAssertEqual(size.totalQuantity.unit, .milliliter)
        XCTAssertEqual(size.totalQuantity.value, 330)
    }

    func testReadsMultipacks() throws {
        let size = try XCTUnwrap(PackageSizeParser.parse("TONNO OLIO 3X80G"))

        XCTAssertEqual(size.packCount, 3)
        XCTAssertEqual(size.unitQuantity.value, 80)
        XCTAssertEqual(size.totalQuantity.value, 240)
        XCTAssertTrue(size.isMultipack)
    }

    func testReadsSpacedMultipacks() throws {
        let size = try XCTUnwrap(PackageSizeParser.parse("ACQUA NATURALE 6 X 0,5 L"))

        XCTAssertEqual(size.packCount, 6)
        XCTAssertEqual(size.totalQuantity.value, 3, accuracy: 0.001)
        XCTAssertEqual(size.totalQuantity.unit, .liter)
    }

    func testIgnoresNamesWithoutASize() {
        XCTAssertNil(PackageSizeParser.parse("PANE INTEGRALE"))
        XCTAssertNil(PackageSizeParser.parse("ZUCCHINE"))
        XCTAssertNil(PackageSizeParser.parse("ARTICOLO 1"))
    }

    func testDoesNotMistakeWordsForUnits() {
        // "GRANA" comincia per "gr" ma non è un'unità di misura.
        XCTAssertNil(PackageSizeParser.parse("GRANA PADANO"))
        XCTAssertNil(PackageSizeParser.parse("2 LIMONI"))
    }

    func testReceiptQuantityMultipliesThePackage() {
        // Due confezioni da 250 g fanno mezzo chilo, non due pezzi.
        let quantity = PackageSizeParser.quantity(forLineText: "RICOTTA 250G", receiptQuantity: 2)

        XCTAssertEqual(quantity.value, 500)
        XCTAssertEqual(quantity.unit, .gram)
    }

    func testFallsBackToPiecesWhenSizeIsUnknown() {
        let quantity = PackageSizeParser.quantity(forLineText: "PANE", receiptQuantity: 3)

        XCTAssertEqual(quantity.value, 3)
        XCTAssertEqual(quantity.unit, .piece)
    }

    func testMakesPantryAndRecipesComparable() {
        // È tutto il punto: lo scontrino dice "1 pezzo", la ricetta chiede 200 g.
        let fromReceipt = PackageSizeParser.quantity(forLineText: "RICOTTA VACCINA 250G", receiptQuantity: 1)
        let recipeNeeds = PantryQuantity(value: 200, unit: .gram)

        XCTAssertTrue(fromReceipt.covers(recipeNeeds))
        XCTAssertFalse(fromReceipt.covers(PantryQuantity(value: 300, unit: .gram)))
    }
}
