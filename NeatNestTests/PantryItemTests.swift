import XCTest
@testable import NeatNest

final class PantryItemTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testFreshnessBuckets() {
        XCTAssertEqual(item(expiresInDays: -1).freshness(referenceDate: now, calendar: calendar), .expired)
        XCTAssertEqual(item(expiresInDays: 0).freshness(referenceDate: now, calendar: calendar), .expiringSoon(daysLeft: 0))
        XCTAssertEqual(item(expiresInDays: 3).freshness(referenceDate: now, calendar: calendar), .expiringSoon(daysLeft: 3))
        XCTAssertEqual(item(expiresInDays: 4).freshness(referenceDate: now, calendar: calendar), .fresh(daysLeft: 4))
        XCTAssertEqual(item(expiresInDays: nil).freshness(referenceDate: now, calendar: calendar), .unknown)
    }

    func testOnlyExpiredAndExpiringAreActionable() {
        XCTAssertTrue(item(expiresInDays: -1).freshness(referenceDate: now, calendar: calendar).isActionable)
        XCTAssertTrue(item(expiresInDays: 2).freshness(referenceDate: now, calendar: calendar).isActionable)
        XCTAssertFalse(item(expiresInDays: 10).freshness(referenceDate: now, calendar: calendar).isActionable)
        XCTAssertFalse(item(expiresInDays: nil).freshness(referenceDate: now, calendar: calendar).isActionable)
    }

    func testMergeRequiresSameStorageAndUnitFamily() {
        let fridge = item(name: "Latte", storage: .fridge)
        let pantry = item(name: "Latte", storage: .pantry)
        XCTAssertFalse(fridge.canMerge(with: pantry))

        var litres = fridge
        litres.quantity = PantryQuantity(value: 1, unit: .liter)
        var grams = fridge
        grams.quantity = PantryQuantity(value: 500, unit: .gram)
        XCTAssertFalse(litres.canMerge(with: grams))
    }

    func testOpenedItemsNeverMerge() {
        // Fondere un latte aperto con uno chiuso falserebbe la scadenza.
        var opened = item(name: "Latte")
        opened.openedAt = now
        let sealed = item(name: "Latte")

        XCTAssertFalse(opened.canMerge(with: sealed))
        XCTAssertFalse(sealed.canMerge(with: opened))
        XCTAssertTrue(sealed.canMerge(with: item(name: "latte")), "Il confronto sul nome ignora le maiuscole")
    }

    func testCatalogIdWinsOverName() {
        var a = item(name: "Latte Arborea")
        a.productCatalogId = "latte-arborea"
        var b = item(name: "Nome scritto diverso")
        b.productCatalogId = "latte-arborea"

        XCTAssertTrue(a.canMerge(with: b))

        b.productCatalogId = "tonno-allolio"
        XCTAssertFalse(a.canMerge(with: b))
    }

    func testFirestoreRoundTripKeepsTheEssentials() {
        var original = item(name: "Yogurt greco", expiresInDays: 5)
        original.brand = "Fage"
        original.notes = "In fondo al frigo"
        original.quantity = PantryQuantity(value: 4, unit: .piece)

        let decoded = PantryItem.fromDocument(id: original.id, data: original.documentData)

        XCTAssertEqual(decoded?.displayName, "Yogurt greco")
        XCTAssertEqual(decoded?.brand, "Fage")
        XCTAssertEqual(decoded?.notes, "In fondo al frigo")
        XCTAssertEqual(decoded?.quantity.value, 4)
        XCTAssertEqual(decoded?.quantity.unit, .piece)
        XCTAssertEqual(decoded?.storage, original.storage)
    }

    private func item(
        name: String = "Latte",
        storage: PantryStorage = .fridge,
        expiresInDays: Int? = 5
    ) -> PantryItem {
        PantryItem(
            userId: "u1",
            name: LocalizedContent(source: name),
            quantity: PantryQuantity(value: 1, unit: .liter),
            storage: storage,
            category: .dairy,
            expiresAt: expiresInDays.flatMap { calendar.date(byAdding: .day, value: $0, to: now) }
        )
    }
}
