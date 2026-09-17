import XCTest
@testable import NeatNest

final class ReceiptTextParserTests: XCTestCase {
    private let parser = ReceiptTextParser()
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private let scontrino = [
        "ESSELUNGA SPA",
        "VIA ROMA 12 - MILANO",
        "P.IVA 04916380159",
        "DOCUMENTO COMMERCIALE",
        "LATTE ARBOREA 1L        1,29",
        "PANE INTEGRALE          2,45",
        "2 X 0,89",
        "YOGURT GRECO            1,78",
        "TONNO OLIO 3X80         3,49",
        "DETERSIVO PIATTI        2,99",
        "TOTALE COMPLESSIVO     11,00",
        "CONTANTE               15,00",
        "RESTO                   4,00",
        "25/08/2026 17:42"
    ]

    func testReadsProductLines() {
        let parsed = parser.parse(lines: scontrino, referenceDate: now)
        let names = parsed.lines.map(\.rawText)

        XCTAssertTrue(names.contains { $0.contains("LATTE ARBOREA") })
        XCTAssertTrue(names.contains { $0.contains("PANE INTEGRALE") })
        XCTAssertTrue(names.contains { $0.contains("DETERSIVO PIATTI") },
                      "Il parser legge tutto; è la dispensa che scarta i non alimentari")
    }

    func testIgnoresTotalsAndPayments() {
        let parsed = parser.parse(lines: scontrino, referenceDate: now)
        let names = parsed.lines.map { $0.rawText.uppercased() }

        for noise in ["TOTALE", "CONTANTE", "RESTO", "DOCUMENTO", "P.IVA"] {
            XCTAssertFalse(names.contains { $0.contains(noise) }, "\(noise) non è un articolo")
        }
    }

    func testReadsDeclaredTotal() {
        XCTAssertEqual(parser.parse(lines: scontrino, referenceDate: now).declaredTotal, 11.00)
    }

    func testReadsRetailerAndDate() throws {
        let parsed = parser.parse(lines: scontrino, referenceDate: now)

        XCTAssertEqual(parsed.retailerName, "ESSELUNGA SPA")

        let date = try XCTUnwrap(parsed.purchaseDate)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 25)
    }

    func testParsesQuantityTimesUnitPrice() throws {
        let parsed = parser.parse(lines: ["ACQUA NATURALE 6 X 0,35   2,10"], referenceDate: now)
        let line = try XCTUnwrap(parsed.lines.first)

        XCTAssertEqual(line.quantity, 6)
        XCTAssertEqual(line.unitPrice, 0.35)
        XCTAssertEqual(line.lineTotal, 2.10)
        XCTAssertFalse(line.rawText.contains("6 X 0,35"), "La quantità non resta nel nome: \(line.rawText)")
    }

    func testParsesLeadingQuantity() throws {
        let parsed = parser.parse(lines: ["3 PANINI                1,50"], referenceDate: now)
        let line = try XCTUnwrap(parsed.lines.first)

        XCTAssertEqual(line.quantity, 3)
        XCTAssertEqual(line.lineTotal, 1.50)
        XCTAssertEqual(line.unitPrice ?? 0, 0.50, accuracy: 0.001)
        XCTAssertEqual(line.rawText, "PANINI")
    }

    func testHandlesDepartmentLetterAfterPrice() throws {
        let parsed = parser.parse(lines: ["MOZZARELLA BUFALA     3,20 A"], referenceDate: now)
        let line = try XCTUnwrap(parsed.lines.first)

        XCTAssertEqual(line.lineTotal, 3.20)
        XCTAssertEqual(line.rawText, "MOZZARELLA BUFALA")
    }

    func testAcceptsDotAsDecimalSeparator() throws {
        let parsed = parser.parse(lines: ["OLIO EVO 1L           7.90"], referenceDate: now)
        XCTAssertEqual(try XCTUnwrap(parsed.lines.first).lineTotal, 7.90)
    }

    func testDefaultsToSingleQuantity() throws {
        let line = try XCTUnwrap(parser.parse(lines: ["BURRO                 2,19"], referenceDate: now).lines.first)

        XCTAssertEqual(line.quantity, 1)
        XCTAssertEqual(line.unitPrice, 2.19)
    }

    func testFlagsInconsistentReceipts() {
        // L'OCR ha perso una riga: la somma non torna e va segnalato.
        let parsed = parser.parse(lines: [
            "CONAD",
            "PASTA                 1,00",
            "TOTALE                9,00"
        ], referenceDate: now)

        XCTAssertFalse(parsed.isConsistent)
    }

    func testConsistentReceiptIsNotFlagged() {
        let parsed = parser.parse(lines: [
            "CONAD",
            "PASTA                 1,00",
            "PANE                  2,00",
            "TOTALE                3,00"
        ], referenceDate: now)

        XCTAssertTrue(parsed.isConsistent)
        XCTAssertEqual(parsed.computedTotal, 3.00, accuracy: 0.001)
    }

    func testReceiptWithoutDeclaredTotalIsNotFlagged() {
        let parsed = parser.parse(lines: ["PANE   2,00"], referenceDate: now)

        XCTAssertNil(parsed.declaredTotal)
        XCTAssertTrue(parsed.isConsistent)
    }

    func testIgnoresLinesWithoutAName() {
        let parsed = parser.parse(lines: ["123456789            1,00", "**                   2,00"], referenceDate: now)

        XCTAssertTrue(parsed.lines.isEmpty, "Un codice a barre non è un prodotto")
    }

    func testEmptyInputProducesEmptyReceipt() {
        let parsed = parser.parse(lines: ["", "   "], referenceDate: now)

        XCTAssertTrue(parsed.lines.isEmpty)
        XCTAssertNil(parsed.retailerName)
    }

    func testScannedLinesFlowIntoThePantryPlan() throws {
        // Il ponte fra OCR e dispensa: le righe lette diventano proposte.
        let parsed = parser.parse(lines: scontrino, referenceDate: now)
        let service = PantryService(locale: Locale(identifier: "it_IT"), calendar: Calendar(identifier: .gregorian))

        let lineItems = parsed.lines.map { line in
            ReceiptLineItem(
                receiptImportId: "r1",
                userId: "u1",
                rawLineText: line.rawText,
                normalizedName: line.rawText.localizedCapitalized,
                quantity: line.quantity,
                lineTotal: line.lineTotal,
                inferredCategory: .other,
                confidence: 0.5
            )
        }

        let plan = service.makeIngestionPlan(
            lineItems: lineItems,
            existingItems: [],
            userId: "u1",
            purchaseDate: now,
            receiptImportId: "r1"
        )

        XCTAssertFalse(plan.candidates.isEmpty)
        XCTAssertTrue(
            plan.skippedLineTexts.contains { $0.localizedCaseInsensitiveContains("detersivo") },
            "Il detersivo non entra in dispensa"
        )
    }
}
