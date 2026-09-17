import XCTest
@testable import NeatNest

final class PantryLevelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testSealedItemIsFullyTrusted() {
        let item = makeItem()

        XCTAssertEqual(item.level, .sealed)
        XCTAssertEqual(item.quantityConfidence, 1)
        XCTAssertFalse(item.isQuantityEstimated)
        XCTAssertEqual(item.remainingFraction, 1)
    }

    func testDeclaringALevelUpdatesQuantityAndLowersConfidence() {
        let half = makeItem().settingLevel(.half, on: now)

        XCTAssertEqual(half.quantity.value, 125, "Metà di 250 g")
        XCTAssertEqual(half.level, .half)
        XCTAssertTrue(half.isQuantityEstimated, "Dichiarata a occhio, non pesata")
        XCTAssertNotNil(half.openedAt, "Dichiarare un livello implica averlo aperto")
    }

    func testInitialQuantityStaysTheReference() {
        let low = makeItem().settingLevel(.low, on: now)

        XCTAssertEqual(low.initialQuantity.value, 250, "La confezione comprata non cambia")
        XCTAssertEqual(low.remainingFraction, 0.2, accuracy: 0.001)
    }

    func testLevelsMapOntoFractions() {
        XCTAssertEqual(PantryLevel.closest(toFraction: 1), .plenty)
        XCTAssertEqual(PantryLevel.closest(toFraction: 0.5), .half)
        XCTAssertEqual(PantryLevel.closest(toFraction: 0.2), .low)
        XCTAssertEqual(PantryLevel.closest(toFraction: 0), .finished)
    }

    func testSyncingLevelLeavesSealedItemsAlone() {
        // Un prodotto mai aperto resta "chiuso" anche se i conti dicono altro.
        let item = makeItem()
        XCTAssertEqual(item.syncingLevelToQuantity().level, .sealed)
    }

    func testSyncingLevelFollowsTheRemainingQuantity() {
        var item = makeItem()
        item.openedAt = now
        item.level = .plenty
        item.quantity = PantryQuantity(value: 50, unit: .gram)

        XCTAssertEqual(item.syncingLevelToQuantity().level, .low)
    }

    func testOpenedCasesNeverOfferSealed() {
        // "Chiuso" non è una risposta sensata a "quanto ne resta?".
        XCTAssertFalse(PantryLevel.openedCases.contains(.sealed))
        XCTAssertEqual(PantryLevel.openedCases.count, 4)
    }

    func testFirestoreRoundTripKeepsLevelAndConfidence() throws {
        let original = makeItem().settingLevel(.low, on: now)
        let decoded = try XCTUnwrap(PantryItem.fromDocument(id: original.id, data: original.documentData))

        XCTAssertEqual(decoded.level, .low)
        XCTAssertEqual(decoded.initialQuantity.value, 250)
        XCTAssertEqual(decoded.quantityConfidence, original.quantityConfidence, accuracy: 0.001)
    }

    func testLegacyDocumentsWithoutLevelStayValid() throws {
        // I documenti scritti prima dei livelli non hanno i campi nuovi.
        let legacy: [String: Any] = [
            "userId": "u1",
            "name": ["it": "Ricotta"],
            "quantity": 250.0,
            "unit": "gram",
            "storage": "fridge",
            "category": "dairy"
        ]

        let decoded = try XCTUnwrap(PantryItem.fromDocument(id: "legacy-1", data: legacy))

        XCTAssertEqual(decoded.level, .sealed)
        XCTAssertEqual(decoded.quantityConfidence, 1)
        XCTAssertEqual(decoded.initialQuantity.value, 250, "Senza dato, la confezione è ciò che resta")
    }

    private func makeItem() -> PantryItem {
        PantryItem(
            userId: "u1",
            name: LocalizedContent(source: "Ricotta"),
            quantity: PantryQuantity(value: 250, unit: .gram),
            storage: .fridge,
            category: .dairy
        )
    }
}
