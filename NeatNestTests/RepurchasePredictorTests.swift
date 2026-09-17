import XCTest
@testable import NeatNest

final class RepurchasePredictorTests: XCTestCase {
    private let predictor = RepurchasePredictor()
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testSuggestsWhatIsOverdue() {
        // Comprato ogni 7 giorni, ne sono passati 14: manca.
        let purchases = events(daysAgo: [28, 21, 14])
        let suggestions = predictor.suggestions(from: purchases, on: now)

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.typicalIntervalDays, 7)
        XCTAssertEqual(suggestions.first?.daysSinceLastPurchase, 14)
    }

    func testStaysQuietWhenNotYetDue() {
        let purchases = events(daysAgo: [14, 7, 2])

        XCTAssertTrue(predictor.suggestions(from: purchases, on: now).isEmpty)
    }

    func testToleratesBeingSlightlyLate() {
        // Un giorno di ritardo su sette non è un motivo per parlare: la spesa
        // magari è stata fatta senza scansionare lo scontrino.
        let purchases = events(daysAgo: [22, 15, 8])

        XCTAssertTrue(predictor.suggestions(from: purchases, on: now).isEmpty)
    }

    func testNeedsAtLeastTwoPurchases() {
        XCTAssertTrue(predictor.suggestions(from: events(daysAgo: [30]), on: now).isEmpty)
    }

    func testStaysQuietWhenHabitsAreIrregular() {
        // 3, 40 e 90 giorni non è un'abitudine, è casualità.
        let purchases = events(daysAgo: [133, 43, 3])
        let suggestions = predictor.suggestions(from: purchases, on: now)

        XCTAssertTrue(suggestions.isEmpty, "Con intervalli ballerini meglio tacere")
    }

    func testDoesNotSuggestWhatIsStillInThePantry() {
        let purchases = events(daysAgo: [28, 21, 14])
        let pantry = [
            PantryItem(
                userId: "u1",
                productCatalogId: "latte",
                name: LocalizedContent(source: "Latte"),
                quantity: PantryQuantity(value: 1, unit: .liter)
            )
        ]

        XCTAssertTrue(predictor.suggestions(from: purchases, pantry: pantry, on: now).isEmpty)
    }

    func testSuggestsAgainOnceThePantryItemIsFinished() {
        let purchases = events(daysAgo: [28, 21, 14])
        var finished = PantryItem(
            userId: "u1",
            productCatalogId: "latte",
            name: LocalizedContent(source: "Latte"),
            quantity: PantryQuantity(value: 1, unit: .liter)
        )
        finished.level = .finished

        XCTAssertEqual(predictor.suggestions(from: purchases, pantry: [finished], on: now).count, 1)
    }

    func testIgnoresImplausibleIntervals() {
        // Due righe dello stesso scontrino non sono due acquisti distinti.
        let purchases = events(daysAgo: [14, 14])

        XCTAssertTrue(predictor.suggestions(from: purchases, on: now).isEmpty)
    }

    func testUsesMedianSoOneOddGapDoesNotDominate() {
        // Una sola spesa saltata non deve raddoppiare l'intervallo stimato.
        let purchases = events(daysAgo: [70, 63, 56, 21, 14])

        XCTAssertEqual(predictor.interval(for: "latte", in: purchases), 7)
    }

    func testMostOverdueComesFirst() {
        let latte = events(daysAgo: [28, 21, 14], key: "latte")
        let caffe = events(daysAgo: [90, 60, 30], key: "caffe", name: "Caffè")

        let suggestions = predictor.suggestions(from: latte + caffe, on: now)

        XCTAssertEqual(suggestions.first?.productKey, "latte", "14 giorni su 7 è più in ritardo di 30 su 30")
    }

    func testBuildsEventsFromReceiptLines() {
        let dates = ["r1": now.addingTimeInterval(-7 * 86_400)]
        let lines = [
            ReceiptLineItem(
                receiptImportId: "r1",
                userId: "u1",
                rawLineText: "LATTE ARBOREA",
                normalizedName: "Latte Arborea",
                productCatalogId: "latte-arborea",
                lineTotal: 1.29,
                inferredCategory: .dairy,
                confidence: 0.9
            ),
            ReceiptLineItem(
                receiptImportId: "sconosciuto",
                userId: "u1",
                rawLineText: "PANE",
                normalizedName: "Pane",
                lineTotal: 2.0,
                inferredCategory: .bakery,
                confidence: 0.8
            )
        ]

        let events = RepurchasePredictor.purchaseEvents(from: lines, receiptDates: dates)

        XCTAssertEqual(events.count, 1, "Una riga senza scontrino datato non è un acquisto collocabile")
        XCTAssertEqual(events.first?.productKey, "latte-arborea")
    }

    private func events(daysAgo: [Double], key: String = "latte", name: String = "Latte") -> [PurchaseEvent] {
        daysAgo.map { days in
            PurchaseEvent(productKey: key, displayName: name, date: now.addingTimeInterval(-days * 86_400))
        }
    }
}
