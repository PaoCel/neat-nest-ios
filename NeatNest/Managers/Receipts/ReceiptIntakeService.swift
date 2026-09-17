import Foundation
import UIKit

/// Cosa è successo dopo aver scansionato uno scontrino.
struct ReceiptIntakeResult: Sendable {
    let triage: ReceiptTriage
    /// La spesa registrata nei movimenti.
    let moneyEntry: MoneyEntry?
    /// L'import creato, quando c'era roba da mettere in dispensa.
    let receiptImport: ReceiptImport?
    /// Righe alimentari pronte per la revisione dispensa.
    let pantryLineItems: [ReceiptLineItem]
    /// L'OCR non torna col totale stampato: qualcosa è sfuggito.
    let hasInconsistentTotal: Bool

    var canFillPantry: Bool { !pantryLineItems.isEmpty }
}

/// Il punto unico da cui entra uno scontrino, qualunque scontrino.
///
/// Non è dentro la spesa di proposito: la farmacia e la ferramenta sono spese
/// come il supermercato. Da qui lo scontrino viene smistato — tutto diventa un
/// movimento in uscita, e solo il cibo prosegue verso la dispensa.
@MainActor
final class ReceiptIntakeService {
    private let scanner: ReceiptScanner
    private let triageService: ReceiptTriageService
    private let importService: ReceiptImportService
    private let moneyRepository: MoneyRepository

    init(
        scanner: ReceiptScanner = ReceiptScanner(),
        triageService: ReceiptTriageService = ReceiptTriageService(),
        importService: ReceiptImportService? = nil,
        moneyRepository: MoneyRepository = MoneyRepository()
    ) {
        self.scanner = scanner
        self.triageService = triageService
        self.importService = importService ?? ReceiptImportService()
        self.moneyRepository = moneyRepository
    }

    func process(images: [UIImage], userId: String) async throws -> ReceiptIntakeResult {
        let parsed = try await scanner.scan(images: images)
        return try await process(parsed: parsed, userId: userId)
    }

    /// Separato dalla scansione per poter essere testato senza fotocamera.
    func process(parsed: ParsedReceipt, userId: String) async throws -> ReceiptIntakeResult {
        guard !parsed.lines.isEmpty else { throw ReceiptScannerError.noTextFound }

        let triage = triageService.triage(parsed)

        // 1. La spesa si registra sempre, anche quando in dispensa non va niente.
        let moneyEntry = try await recordExpense(for: triage, userId: userId)

        // 2. Solo la parte alimentare diventa un import verso la dispensa.
        var receiptImport: ReceiptImport?
        var pantryLineItems: [ReceiptLineItem] = []

        if triage.hasFood {
            let foodOnly = ParsedReceipt(
                retailerName: parsed.retailerName,
                purchaseDate: parsed.purchaseDate,
                declaredTotal: nil,
                lines: triage.foodLines
            )

            let result = try await importService.importScannedReceipt(foodOnly, userId: userId)
            receiptImport = result.receipt
            pantryLineItems = result.lineItems
        }

        return ReceiptIntakeResult(
            triage: triage,
            moneyEntry: moneyEntry,
            receiptImport: receiptImport,
            pantryLineItems: pantryLineItems,
            hasInconsistentTotal: !parsed.isConsistent
        )
    }

    private func recordExpense(for triage: ReceiptTriage, userId: String) async throws -> MoneyEntry? {
        let amount = triage.total
        guard amount > 0 else { return nil }

        let entry = MoneyEntry(
            userId: userId,
            kind: .expense,
            amount: amount,
            note: triage.retailerName,
            date: triage.purchaseDate,
            source: .receipt
        )

        try await moneyRepository.save(entry)
        return entry
    }
}
