import XCTest
@testable import NeatNest

final class ReceiptTriageTests: XCTestCase {
    private let service = ReceiptTriageService(locale: Locale(identifier: "it_IT"))
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testSeparatesFoodFromEverythingElse() {
        let triage = service.triage(receipt(with: [
            line("LATTE ARBOREA 1L", 1.29),
            line("PANE INTEGRALE", 2.45),
            line("DETERSIVO PIATTI", 2.99),
            line("CARTA IGIENICA", 4.50)
        ]))

        XCTAssertEqual(triage.foodLines.count, 2)
        XCTAssertEqual(triage.otherLines.count, 2)
        XCTAssertEqual(triage.kind, .mixed)
    }

    func testGroceryOnlyReceipt() {
        let triage = service.triage(receipt(with: [
            line("LATTE ARBOREA 1L", 1.29),
            line("PASTA BARILLA", 1.19)
        ]))

        XCTAssertEqual(triage.kind, .grocery)
        XCTAssertTrue(triage.otherLines.isEmpty)
    }

    func testNonGroceryReceipt() {
        // Farmacia, ferramenta: è una spesa, ma in dispensa non ci va niente.
        let triage = service.triage(receipt(with: [
            line("SHAMPOO", 4.90),
            line("SAPONE MANI", 2.30)
        ]))

        XCTAssertEqual(triage.kind, .nonGrocery)
        XCTAssertFalse(triage.hasFood)
    }

    func testTotalsAreSplitByKind() {
        let triage = service.triage(receipt(with: [
            line("LATTE", 1.00),
            line("PANE", 2.00),
            line("DETERSIVO", 3.00)
        ]))

        XCTAssertEqual(triage.foodTotal, 3.00, accuracy: 0.001)
        XCTAssertEqual(triage.otherTotal, 3.00, accuracy: 0.001)
    }

    func testDeclaredTotalWinsOverTheSumOfLines() {
        // Se l'OCR ha perso una riga, il totale stampato resta più affidabile
        // della somma di quello che siamo riusciti a leggere.
        var parsed = receipt(with: [line("LATTE", 1.00)])
        parsed.declaredTotal = 12.50

        XCTAssertEqual(service.triage(parsed).total, 12.50)
    }

    func testFallsBackToTheSumWhenNoTotalIsPrinted() {
        let triage = service.triage(receipt(with: [line("LATTE", 1.00), line("PANE", 2.00)]))

        XCTAssertEqual(triage.total, 3.00, accuracy: 0.001)
    }

    func testUnknownRetailerStillProducesAName() {
        var parsed = receipt(with: [line("LATTE", 1.00)])
        parsed.retailerName = nil

        XCTAssertFalse(service.triage(parsed).retailerName.isEmpty)
    }

    private func receipt(with lines: [ParsedReceiptLine]) -> ParsedReceipt {
        ParsedReceipt(retailerName: "ESSELUNGA", purchaseDate: now, declaredTotal: nil, lines: lines)
    }

    private func line(_ text: String, _ total: Double) -> ParsedReceiptLine {
        ParsedReceiptLine(rawText: text, quantity: 1, unitPrice: total, lineTotal: total)
    }
}
