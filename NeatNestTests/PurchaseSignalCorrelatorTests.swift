import XCTest
@testable import NeatNest

final class PurchaseSignalCorrelatorTests: XCTestCase {
    private let correlator = PurchaseSignalCorrelator()
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - Le due fonti insieme

    func testTwoSourcesForTheSamePurchaseProduceOneSinglePrompt() {
        // È il punto di tutto il meccanismo: due notifiche per una spesa sola
        // sono il modo più rapido per farsi disattivare.
        let prompts = correlator.prompts(from: [
            wallet(amount: 47.30, merchant: "ESSELUNGA SPA", minutesAgo: 20),
            geofence(merchant: "Esselunga Via Roma", retailerId: "ess-roma", minutesAgo: 10)
        ])

        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(prompts[0].confidence, .confirmed)
        XCTAssertEqual(prompts[0].sources, [.wallet, .geofence])
    }

    func testTheMergedPromptTakesTheBestOfBothSources() {
        let prompts = correlator.prompts(from: [
            wallet(amount: 47.30, merchant: "ESSELUNGA SPA", minutesAgo: 20),
            geofence(merchant: "Esselunga Via Roma", retailerId: "ess-roma", minutesAgo: 10)
        ])

        XCTAssertEqual(prompts[0].amount, 47.30, "L'importo lo sa solo Wallet")
        XCTAssertEqual(prompts[0].retailerId, "ess-roma", "Il punto vendita lo sa solo la posizione")
        XCTAssertEqual(prompts[0].merchantName, "Esselunga Via Roma", "Vince il nome del negozio reale")
    }

    // MARK: - Una fonte sola

    func testWalletAloneStillAsks() {
        let prompts = correlator.prompts(from: [wallet(amount: 12.50, merchant: "CONAD", minutesAgo: 5)])

        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(prompts[0].confidence, .likely)
        XCTAssertEqual(prompts[0].amount, 12.50)
    }

    func testGeofenceAloneStillAsks() {
        // Il caso dei contanti: Wallet non vede niente, la posizione sì.
        let prompts = correlator.prompts(from: [geofence(merchant: "Tigros", retailerId: "tigros-1", minutesAgo: 5)])

        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(prompts[0].confidence, .likely)
        XCTAssertNil(prompts[0].amount)
    }

    // MARK: - Quando NON si deve unire

    func testSignalsTooFarApartInTimeAreSeparatePurchases() {
        let prompts = correlator.prompts(from: [
            wallet(amount: 47.30, merchant: "ESSELUNGA", minutesAgo: 300),
            geofence(merchant: "Esselunga", retailerId: "ess-roma", minutesAgo: 5)
        ])

        XCTAssertEqual(prompts.count, 2, "Cinque ore fa è un'altra spesa")
    }

    func testDifferentMerchantsAreNotMerged() {
        // Pagare dal benzinaio mentre si esce dal supermercato sono due cose.
        let prompts = correlator.prompts(from: [
            wallet(amount: 60.00, merchant: "ENI STAZIONE", minutesAgo: 15),
            geofence(merchant: "Esselunga Via Roma", retailerId: "ess-roma", minutesAgo: 10)
        ])

        XCTAssertEqual(prompts.count, 2)
    }

    func testTwoWalletSignalsFarApartStayDistinct() {
        let prompts = correlator.prompts(from: [
            wallet(amount: 10, merchant: "CONAD", minutesAgo: 200),
            wallet(amount: 25, merchant: "CONAD", minutesAgo: 5)
        ])

        XCTAssertEqual(prompts.count, 2, "Due spese nello stesso posto in momenti diversi")
    }

    // MARK: - Doppioni

    func testTheSameSourceFiringTwiceIsOnePurchase() {
        // L'automazione Wallet è nota per scattare in modo irregolare.
        let prompts = correlator.prompts(from: [
            wallet(amount: 47.30, merchant: "ESSELUNGA", minutesAgo: 12),
            wallet(amount: 47.30, merchant: "ESSELUNGA", minutesAgo: 10)
        ])

        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(prompts[0].signals.count, 2)
    }

    // MARK: - Nomi negozio

    func testMerchantNamesMatchAcrossFormats() {
        XCTAssertTrue(PurchaseSignalCorrelator.merchantsMatch("ESSELUNGA SPA", "Esselunga Via Roma"))
        XCTAssertTrue(PurchaseSignalCorrelator.merchantsMatch("CONAD CITY", "Conad"))
        XCTAssertFalse(PurchaseSignalCorrelator.merchantsMatch("ESSELUNGA", "Carrefour"))
    }

    func testUnknownMerchantDoesNotBlockCorrelation() {
        // Se una fonte non sa da chi, il tempo basta a metterle insieme.
        XCTAssertTrue(PurchaseSignalCorrelator.merchantsMatch(nil, "Esselunga"))
    }

    // MARK: - Testo mostrato

    func testMessageSaysOnlyWhatIsActuallyKnown() {
        let both = correlator.prompts(from: [
            wallet(amount: 47.30, merchant: "ESSELUNGA SPA", minutesAgo: 15),
            geofence(merchant: "Esselunga Via Roma", retailerId: "ess-roma", minutesAgo: 10)
        ])[0]
        XCTAssertTrue(both.notificationBody.contains("Esselunga"))
        XCTAssertTrue(both.notificationBody.contains("47"))

        let geofenceOnly = correlator.prompts(from: [
            geofence(merchant: "Tigros", retailerId: "t1", minutesAgo: 5)
        ])[0]
        XCTAssertFalse(geofenceOnly.notificationBody.contains("47"), "Senza importo non si inventa una cifra")
        XCTAssertTrue(geofenceOnly.notificationBody.contains("Tigros"))
    }

    func testNewestPromptComesFirst() {
        let prompts = correlator.prompts(from: [
            wallet(amount: 10, merchant: "CONAD", minutesAgo: 300),
            wallet(amount: 25, merchant: "ESSELUNGA", minutesAgo: 5)
        ])

        XCTAssertEqual(prompts.first?.amount, 25)
    }

    func testNoSignalsNoPrompts() {
        XCTAssertTrue(correlator.prompts(from: []).isEmpty)
    }

    // MARK: - Helper

    private func wallet(amount: Double, merchant: String, minutesAgo: Double) -> PurchaseSignal {
        PurchaseSignal(
            source: .wallet,
            merchantName: merchant,
            amount: amount,
            detectedAt: now.addingTimeInterval(-minutesAgo * 60)
        )
    }

    private func geofence(merchant: String, retailerId: String, minutesAgo: Double) -> PurchaseSignal {
        PurchaseSignal(
            source: .geofence,
            merchantName: merchant,
            retailerId: retailerId,
            detectedAt: now.addingTimeInterval(-minutesAgo * 60)
        )
    }
}
