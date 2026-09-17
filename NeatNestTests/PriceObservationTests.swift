import XCTest
@testable import NeatNest

final class PriceObservationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private let aggregator = PriceObservationAggregator()

    // MARK: - Fiducia

    func testReceiptsAreTrustedMoreThanFlyersAndSeededData() {
        XCTAssertGreaterThan(RetailerPriceSourceType.receipt.baseConfidence, RetailerPriceSourceType.flyer.baseConfidence)
        XCTAssertGreaterThan(RetailerPriceSourceType.flyer.baseConfidence, RetailerPriceSourceType.seeded.baseConfidence)
    }

    func testConfidenceHalvesAfterTheHalfLife() {
        let observation = makeObservation(daysAgo: 21)

        XCTAssertEqual(observation.confidence(on: now, halfLifeDays: 21), 0.5, accuracy: 0.01)
    }

    func testFreshObservationKeepsFullConfidence() {
        XCTAssertEqual(makeObservation(daysAgo: 0).confidence(on: now), 1, accuracy: 0.01)
    }

    func testObservationWithoutProductLinkIsUnusable() {
        let orphan = PriceObservation(retailerId: "esselunga", rawLabel: "ARTICOLO 1", price: 1.29)

        XCTAssertFalse(orphan.isUsable, "Senza aggancio al catalogo non si confronta con niente")
    }

    func testNonPositivePriceIsUnusable() {
        let free = PriceObservation(
            retailerId: "esselunga",
            productCatalogId: "latte",
            rawLabel: "LATTE",
            price: 0
        )

        XCTAssertFalse(free.isUsable)
    }

    // MARK: - Aggregazione

    func testMedianIgnoresASingleOcrMisread() {
        // Un "12,90" letto male non deve spostare il prezzo del latte.
        let observations = [
            makeObservation(price: 1.29, daysAgo: 1),
            makeObservation(price: 1.29, daysAgo: 2),
            makeObservation(price: 12.90, daysAgo: 3),
            makeObservation(price: 1.35, daysAgo: 4),
            makeObservation(price: 1.29, daysAgo: 5)
        ]

        let prices = aggregator.aggregate(observations, on: now)

        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices[0].basePrice, 1.29, accuracy: 0.001)
    }

    func testKeepsRetailersSeparate() {
        let observations = [
            makeObservation(retailerId: "esselunga", price: 1.29, daysAgo: 1),
            makeObservation(retailerId: "conad", price: 1.49, daysAgo: 1)
        ]

        let prices = aggregator.aggregate(observations, on: now)

        XCTAssertEqual(prices.count, 2)
        XCTAssertEqual(Set(prices.map(\.retailerId)), ["esselunga", "conad"])
    }

    func testDropsObservationsOlderThanTheWindow() {
        let prices = aggregator.aggregate([makeObservation(daysAgo: 200)], on: now)

        XCTAssertTrue(prices.isEmpty, "Un prezzo di sei mesi fa non è un prezzo")
    }

    func testLastUpdatedFollowsTheNewestObservation() throws {
        let observations = [makeObservation(daysAgo: 30), makeObservation(daysAgo: 2)]
        let price = try XCTUnwrap(aggregator.aggregate(observations, on: now).first)

        let ageDays = now.timeIntervalSince(price.lastUpdatedAt) / 86_400
        XCTAssertEqual(ageDays, 2, accuracy: 0.1)
    }

    func testAggregatedConfidenceDecaysWithAge() throws {
        let fresh = try XCTUnwrap(aggregator.aggregate([makeObservation(daysAgo: 1)], on: now).first)
        let stale = try XCTUnwrap(aggregator.aggregate([makeObservation(daysAgo: 60)], on: now).first)

        XCTAssertGreaterThan(fresh.sourceConfidence, stale.sourceConfidence)
        XCTAssertLessThan(stale.sourceConfidence, 0.3, "Due mesi di ritardo devono vedersi")
    }

    func testPromoIsOnlyDeclaredWhenTheNewestObservationHadOne() throws {
        let withPromo = [
            makeObservation(price: 1.79, promoPrice: 1.29, daysAgo: 1),
            makeObservation(price: 1.79, daysAgo: 10)
        ]
        XCTAssertNotNil(try XCTUnwrap(aggregator.aggregate(withPromo, on: now).first).promoPrice)

        let expiredPromo = [
            makeObservation(price: 1.79, daysAgo: 1),
            makeObservation(price: 1.79, promoPrice: 1.29, daysAgo: 10)
        ]
        XCTAssertNil(
            try XCTUnwrap(aggregator.aggregate(expiredPromo, on: now).first).promoPrice,
            "Uno sconto vecchio non è uno sconto"
        )
    }

    func testUnusableObservationsNeverBecomePrices() {
        let observations = [
            PriceObservation(retailerId: "esselunga", rawLabel: "ARTICOLO 1", price: 1.29),
            makeObservation(price: 1.29, daysAgo: 1)
        ]

        XCTAssertEqual(aggregator.aggregate(observations, on: now).count, 1)
    }

    func testFirestoreRoundTrip() throws {
        let original = makeObservation(price: 1.29, promoPrice: 0.99, daysAgo: 3)
        let decoded = try XCTUnwrap(PriceObservation.fromDocument(id: original.id, data: original.documentData))

        XCTAssertEqual(decoded.retailerId, original.retailerId)
        XCTAssertEqual(decoded.price, original.price, accuracy: 0.001)
        XCTAssertEqual(decoded.promoPrice ?? 0, 0.99, accuracy: 0.001)
        XCTAssertEqual(decoded.source, .receipt)
    }

    func testDocumentNeverCarriesTheContributorIdentity() {
        // Il prezzo non è un dato personale, il carrello di una persona sì.
        let data = makeObservation().documentData

        XCTAssertNil(data["userId"])
        XCTAssertNil(data["contributorId"])
    }

    // MARK: - Helper

    private func makeObservation(
        retailerId: String = "esselunga",
        price: Double = 1.29,
        promoPrice: Double? = nil,
        daysAgo: Double = 0
    ) -> PriceObservation {
        PriceObservation(
            retailerId: retailerId,
            productCatalogId: "latte-arborea",
            rawLabel: "LATTE ARBOREA 1L",
            price: price,
            promoPrice: promoPrice,
            observedAt: now.addingTimeInterval(-daysAgo * 86_400),
            source: .receipt
        )
    }
}
