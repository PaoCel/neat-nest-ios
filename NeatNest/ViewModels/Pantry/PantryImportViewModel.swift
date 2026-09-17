import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PantryImportViewModel {
    private(set) var receipts: [ReceiptImport] = []
    private(set) var selectedReceipt: ReceiptImport?
    private(set) var plan: PantryIngestionPlan?
    private(set) var isLoading = false
    private(set) var isApplying = false
    private(set) var didApply = false
    private(set) var isProcessingScan = false
    /// L'OCR ha letto meno di quanto lo scontrino dichiara: va detto, non nascosto.
    private(set) var scanWarning: String?
    var errorMessage: String?

    private let userId: String
    private let expenseRepository: GroceryExpenseRepository
    private let pantryRepository: PantryRepository
    private let service: PantryService
    private let importService: ReceiptImportService
    private let scanner = ReceiptScanner()

    @ObservationIgnored private var lineItemsByReceipt: [String: [ReceiptLineItem]] = [:]
    @ObservationIgnored private var pantryItems: [PantryItem] = []

    init(
        userId: String,
        expenseRepository: GroceryExpenseRepository = GroceryExpenseRepository(),
        pantryRepository: PantryRepository = PantryRepository(),
        service: PantryService? = nil,
        importService: ReceiptImportService? = nil
    ) {
        self.userId = userId
        self.expenseRepository = expenseRepository
        self.pantryRepository = pantryRepository
        self.service = service ?? PantryService(repository: pantryRepository)
        self.importService = importService ?? ReceiptImportService()
    }

    var canScan: Bool {
        ReceiptScannerView.isAvailable
    }

    var hasReceipts: Bool { !receipts.isEmpty }

    var includedCount: Int {
        plan?.includedCandidates.count ?? 0
    }

    var reviewCount: Int {
        plan?.reviewCount ?? 0
    }

    // MARK: - Caricamento

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let receiptsTask = expenseRepository.fetchReceiptImports(for: userId)
            async let lineItemsTask = expenseRepository.fetchReceiptLineItems(for: userId)
            async let pantryTask = pantryRepository.fetchItems(for: userId)

            let (loadedReceipts, loadedLines, loadedPantry) = try await (receiptsTask, lineItemsTask, pantryTask)

            receipts = loadedReceipts.sorted { $0.purchaseDate > $1.purchaseDate }
            lineItemsByReceipt = Dictionary(grouping: loadedLines, by: \.receiptImportId)
            pantryItems = loadedPantry

            if let first = receipts.first {
                select(first)
            }
        } catch {
            errorMessage = String(
                localized: "pantry.import.error.load",
                defaultValue: "Non riesco a leggere gli scontrini. Riprova."
            )
        }
    }

    // MARK: - Scansione

    /// Legge le foto dello scontrino, le salva come import e le porta subito in
    /// revisione: l'utente vede il risultato senza passare da altre schermate.
    func importScanned(images: [UIImage]) async {
        guard !images.isEmpty else { return }

        isProcessingScan = true
        errorMessage = nil
        scanWarning = nil
        defer { isProcessingScan = false }

        do {
            let parsed = try await scanner.scan(images: images)

            guard !parsed.lines.isEmpty else {
                errorMessage = String(
                    localized: "receipt.scan.error.noLines",
                    defaultValue: "Non ho riconosciuto nessun articolo. Riprova inquadrando tutto lo scontrino."
                )
                return
            }

            if !parsed.isConsistent {
                scanWarning = String(
                    localized: "receipt.scan.warning.mismatch",
                    defaultValue: "La somma degli articoli non torna con il totale stampato: controlla le righe prima di confermare."
                )
            }

            let result = try await importService.importScannedReceipt(parsed, userId: userId)

            await load()
            if let imported = receipts.first(where: { $0.id == result.receipt.id }) {
                select(imported)
            }
        } catch let error as ReceiptScannerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = String(
                localized: "receipt.scan.error.import",
                defaultValue: "Non riesco a salvare lo scontrino letto. Riprova."
            )
        }
    }

    func dismissScanWarning() {
        scanWarning = nil
    }

    func select(_ receipt: ReceiptImport) {
        selectedReceipt = receipt
        didApply = false

        plan = service.makeIngestionPlan(
            lineItems: lineItemsByReceipt[receipt.id] ?? [],
            existingItems: pantryItems,
            userId: userId,
            purchaseDate: receipt.purchaseDate,
            receiptImportId: receipt.id
        )
    }

    // MARK: - Modifiche prima della conferma

    func setIncluded(_ isIncluded: Bool, for candidateId: String) {
        mutate(candidateId) { $0.isIncluded = isIncluded }
    }

    func setName(_ name: String, for candidateId: String) {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else { return }

        mutate(candidateId) { candidate in
            candidate.item.name = LocalizedContent(source: trimmed)
        }
    }

    func setStorage(_ storage: PantryStorage, for candidateId: String) {
        mutate(candidateId) { $0.item.storage = storage }
    }

    func setCategory(_ category: GrocerySpendingCategory, for candidateId: String) {
        mutate(candidateId) { $0.item.category = category }
    }

    func setQuantity(_ value: Double, unit: PantryUnit, for candidateId: String) {
        guard value > 0 else { return }
        mutate(candidateId) { $0.item.quantity = PantryQuantity(value: value, unit: unit) }
    }

    func setExpiry(_ date: Date?, for candidateId: String) {
        mutate(candidateId) { candidate in
            candidate.item.expiresAt = date
            candidate.item.isExpiryEstimated = date == nil
        }
    }

    func includeAll() {
        guard var plan else { return }
        for index in plan.candidates.indices {
            plan.candidates[index].isIncluded = true
        }
        self.plan = plan
    }

    func excludeAll() {
        guard var plan else { return }
        for index in plan.candidates.indices {
            plan.candidates[index].isIncluded = false
        }
        self.plan = plan
    }

    // MARK: - Conferma

    func apply() async {
        guard let plan, !plan.includedCandidates.isEmpty else { return }

        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        do {
            try await service.apply(plan)
            didApply = true
        } catch {
            errorMessage = PantryError.persistenceFailed.errorDescription
        }
    }

    private func mutate(_ candidateId: String, _ transform: (inout PantryIngestionCandidate) -> Void) {
        guard var plan, let index = plan.candidates.firstIndex(where: { $0.id == candidateId }) else { return }
        transform(&plan.candidates[index])
        self.plan = plan
    }
}
