import XCTest
@testable import NeatNest

final class PantryIngestionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private lazy var service = PantryService(
        locale: Locale(identifier: "it_IT"),
        calendar: Calendar(identifier: .gregorian)
    )

    func testSkipsNonFoodLines() {
        let plan = makePlan(lines: [line("DETERSIVO PIATTI", category: .household)])

        XCTAssertTrue(plan.candidates.isEmpty)
        XCTAssertEqual(plan.skippedLineTexts, ["DETERSIVO PIATTI"])
    }

    func testMergesTheSameProductTwiceOnOneReceipt() {
        let plan = makePlan(lines: [
            line("LATTE ARBOREA", normalized: "Latte Arborea", quantity: 1, category: .dairy),
            line("LATTE ARBOREA", normalized: "Latte Arborea", quantity: 2, category: .dairy)
        ])

        XCTAssertEqual(plan.candidates.count, 1, "Due righe uguali non fanno due prodotti")
        XCTAssertEqual(plan.candidates.first?.item.quantity.value, 3)
    }

    func testMergesWithWhatIsAlreadyInThePantry() {
        let existing = PantryItem(
            userId: "u1",
            name: LocalizedContent(source: "Latte Arborea"),
            quantity: PantryQuantity(value: 1, unit: .piece),
            storage: .fridge,
            category: .dairy
        )

        let plan = makePlan(
            lines: [line("LATTE ARBOREA", normalized: "Latte Arborea", quantity: 2, category: .dairy)],
            existing: [existing]
        )

        XCTAssertEqual(plan.candidates.count, 1)
        XCTAssertTrue(plan.candidates[0].kind.isMerge)
        XCTAssertEqual(plan.candidates[0].item.id, existing.id, "La fusione aggiorna la riga esistente")
        XCTAssertEqual(plan.candidates[0].item.quantity.value, 3)
    }

    func testUnmatchedLinesAreFlaggedForReview() {
        let plan = makePlan(lines: [
            line("ARTICOLO 1", normalized: "Articolo 1", category: .other),
            line("PASTA", normalized: "Pasta", catalogId: "pasta-barilla", category: .pantry)
        ])

        let review = plan.candidates.filter(\.needsReview)
        XCTAssertEqual(review.count, 1)
        XCTAssertEqual(review.first?.rawLineText, "ARTICOLO 1")
        XCTAssertEqual(plan.reviewCount, 1)
    }

    func testOnlyIncludedCandidatesCount() {
        var plan = makePlan(lines: [
            line("PASTA", normalized: "Pasta", category: .pantry),
            line("TONNO", normalized: "Tonno", category: .pantry)
        ])

        XCTAssertEqual(plan.includedCandidates.count, 2, "Di default tutto è spuntato")

        plan.candidates[0].isIncluded = false
        XCTAssertEqual(plan.includedCandidates.count, 1)
    }

    func testEstimatedExpiryIsAttachedToCandidates() {
        let plan = makePlan(lines: [line("LATTE", normalized: "Latte", category: .dairy)])

        let candidate = try? XCTUnwrap(plan.candidates.first)
        XCTAssertNotNil(candidate?.item.expiresAt)
        XCTAssertTrue(candidate?.item.isExpiryEstimated ?? false)
        XCTAssertEqual(candidate?.item.source, .receipt)
    }

    // MARK: - Helpers

    private func makePlan(lines: [ReceiptLineItem], existing: [PantryItem] = []) -> PantryIngestionPlan {
        service.makeIngestionPlan(
            lineItems: lines,
            existingItems: existing,
            userId: "u1",
            purchaseDate: now,
            receiptImportId: "receipt-1"
        )
    }

    private func line(
        _ raw: String,
        normalized: String? = nil,
        catalogId: String? = nil,
        quantity: Double = 1,
        category: GrocerySpendingCategory
    ) -> ReceiptLineItem {
        ReceiptLineItem(
            receiptImportId: "receipt-1",
            userId: "u1",
            rawLineText: raw,
            normalizedName: normalized ?? raw,
            productCatalogId: catalogId,
            quantity: quantity,
            lineTotal: 1.0,
            inferredCategory: category,
            confidence: 0.8
        )
    }
}
