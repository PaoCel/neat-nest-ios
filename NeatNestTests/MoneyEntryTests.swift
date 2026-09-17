import XCTest
@testable import NeatNest

final class MoneyEntryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testExpensesCountNegativeInTheBalance() {
        let balance = MoneyBalance(entries: [
            entry(kind: .income, amount: 1500),
            entry(kind: .expense, amount: 400),
            entry(kind: .expense, amount: 100)
        ])

        XCTAssertEqual(balance.income, 1500)
        XCTAssertEqual(balance.expenses, 500)
        XCTAssertEqual(balance.delta, 1000)
        XCTAssertTrue(balance.isPositive)
    }

    func testNegativeBalanceIsFlagged() {
        let balance = MoneyBalance(entries: [entry(kind: .expense, amount: 50)])

        XCTAssertEqual(balance.delta, -50)
        XCTAssertFalse(balance.isPositive)
    }

    func testEmptyBalanceIsZero() {
        XCTAssertEqual(MoneyBalance(entries: []).delta, 0)
    }

    func testAmountIsAlwaysStoredPositive() {
        // Il segno lo dà il tipo, non il numero: due fonti di verità sarebbero
        // una di troppo.
        let expense = entry(kind: .expense, amount: -30)

        XCTAssertEqual(expense.amount, 30)
        XCTAssertEqual(expense.signedAmount, -30)
    }

    func testIncomeIsSignedPositive() {
        XCTAssertEqual(entry(kind: .income, amount: 30).signedAmount, 30)
    }

    func testFirestoreRoundTrip() throws {
        let original = MoneyEntry(
            userId: "u1",
            kind: .expense,
            amount: 47.30,
            note: "Esselunga",
            date: now,
            source: .receipt,
            receiptImportId: "r1"
        )

        let decoded = try XCTUnwrap(MoneyEntry.fromDocument(id: original.id, data: original.documentData))

        XCTAssertEqual(decoded.kind, .expense)
        XCTAssertEqual(decoded.amount, 47.30, accuracy: 0.001)
        XCTAssertEqual(decoded.note, "Esselunga")
        XCTAssertEqual(decoded.source, .receipt)
        XCTAssertEqual(decoded.receiptImportId, "r1")
    }

    func testZeroAmountIsRejectedOnDecode() {
        let data: [String: Any] = ["userId": "u1", "kind": "expense", "amount": 0.0]

        XCTAssertNil(MoneyEntry.fromDocument(id: "x", data: data))
    }

    func testPeriodStartDates() {
        XCTAssertNotNil(MoneyPeriod.month.startDate(from: now))
        XCTAssertNotNil(MoneyPeriod.year.startDate(from: now))
        XCTAssertNil(MoneyPeriod.all.startDate(from: now), "«Tutto» non ha una data d'inizio")
    }

    private func entry(kind: MoneyEntry.Kind, amount: Double) -> MoneyEntry {
        MoneyEntry(userId: "u1", kind: kind, amount: amount, note: "", date: now)
    }
}
