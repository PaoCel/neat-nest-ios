import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class SmartGrocerySpendingViewModel {
    private(set) var summary: GrocerySpendingSummary?
    private(set) var categorySummaries: [GrocerySpendingCategorySummary] = []
    private(set) var recentReceipts: [ReceiptImport] = []
    private(set) var recentPurchases: [PurchaseHistoryEntry] = []
    private(set) var templates: [DemoReceiptTemplate] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    var lastImportResult: ReceiptImportResult?
    var errorMessage: String?

    private let userId: String?
    private let expenseRepository: GroceryExpenseRepository
    private let importService: ReceiptImportService

    @ObservationIgnored
    private nonisolated(unsafe) var importsListener: ListenerRegistration?
    @ObservationIgnored
    private nonisolated(unsafe) var lineItemsListener: ListenerRegistration?
    private var allImports: [ReceiptImport] = []
    private var allLineItems: [ReceiptLineItem] = []
    private var hasLoaded = false

    init(
        userSession: UserSession,
        expenseRepository: GroceryExpenseRepository = GroceryExpenseRepository(),
        groceryRepository: SmartGroceryRepository = SmartGroceryRepository()
    ) {
        self.userId = userSession.currentUserId
        self.expenseRepository = expenseRepository
        self.importService = ReceiptImportService(
            expenseRepository: expenseRepository,
            groceryRepository: groceryRepository
        )
    }

    deinit {
        importsListener?.remove()
        lineItemsListener?.remove()
    }

    var hasImportedReceipts: Bool {
        !allImports.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let userId, !userId.isEmpty else {
            errorMessage = "Non riesco a capire quale account usare per lo storico spesa."
            return
        }

        isLoading = true

        do {
            templates = try await importService.loadTemplates()
        } catch {
            errorMessage = "Non riesco a preparare le demo receipt. \(error.localizedDescription)"
        }

        startObserving(userId: userId)
    }

    func importTemplate(_ template: DemoReceiptTemplate) async {
        guard let userId else {
            errorMessage = "Account non disponibile."
            return
        }

        errorMessage = nil
        isImporting = true
        defer { isImporting = false }

        do {
            lastImportResult = try await importService.importTemplate(template, userId: userId)
        } catch {
            errorMessage = "Non riesco a importare la demo receipt. \(error.localizedDescription)"
        }
    }

    func clearLastImportResult() {
        lastImportResult = nil
    }

    private func startObserving(userId: String) {
        importsListener?.remove()
        lineItemsListener?.remove()

        importsListener = expenseRepository.observeReceiptImports(for: userId) { [weak self] result in
            guard let self else { return }

            _Concurrency.Task { @MainActor in
                switch result {
                case .success(let imports):
                    self.allImports = imports
                    self.refreshDerivedState()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare gli scontrini importati. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }

        lineItemsListener = expenseRepository.observeReceiptLineItems(for: userId) { [weak self] result in
            guard let self else { return }

            _Concurrency.Task { @MainActor in
                switch result {
                case .success(let lineItems):
                    self.allLineItems = lineItems
                    self.refreshDerivedState()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare lo storico acquisti. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshDerivedState() {
        recentReceipts = Array(allImports.prefix(4))

        let receiptsById = Dictionary(uniqueKeysWithValues: allImports.map { ($0.id, $0) })
        recentPurchases = allLineItems
            .compactMap { lineItem in
                guard let receipt = receiptsById[lineItem.receiptImportId] else { return nil }
                return PurchaseHistoryEntry(receipt: receipt, lineItem: lineItem)
            }
            .sorted { lhs, rhs in
                if lhs.receipt.purchaseDate != rhs.receipt.purchaseDate {
                    return lhs.receipt.purchaseDate > rhs.receipt.purchaseDate
                }
                return lhs.lineItem.lineTotal > rhs.lineItem.lineTotal
            }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let receiptsInWindow = allImports.filter { $0.purchaseDate >= startDate }
        let receiptIdsInWindow = Set(receiptsInWindow.map(\.id))
        let lineItemsInWindow = allLineItems.filter { receiptIdsInWindow.contains($0.receiptImportId) }

        let totalSpend = receiptsInWindow.reduce(0) { $0 + $1.totalAmount }
        let averageBasket = receiptsInWindow.isEmpty ? 0 : totalSpend / Double(receiptsInWindow.count)

        summary = GrocerySpendingSummary(
            totalSpend: totalSpend,
            receiptCount: receiptsInWindow.count,
            averageBasket: averageBasket,
            periodStart: startDate,
            periodEnd: endDate
        )

        let grouped = Dictionary(grouping: lineItemsInWindow, by: \.inferredCategory)
        categorySummaries = grouped
            .map { category, items in
                let amount = items.reduce(0) { $0 + $1.lineTotal }
                return GrocerySpendingCategorySummary(
                    category: category,
                    amount: amount,
                    itemCount: items.count,
                    share: totalSpend > 0 ? amount / totalSpend : 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount {
                    return lhs.amount > rhs.amount
                }
                return lhs.category.localizedTitle.localizedCaseInsensitiveCompare(rhs.category.localizedTitle) == .orderedAscending
            }

        isLoading = false
    }
}

extension SmartGrocerySpendingViewModel {
    convenience init(
        previewSummary: GrocerySpendingSummary,
        categorySummaries: [GrocerySpendingCategorySummary],
        recentReceipts: [ReceiptImport],
        recentPurchases: [PurchaseHistoryEntry],
        templates: [DemoReceiptTemplate],
        lastImportResult: ReceiptImportResult? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(userSession: PreviewSupport.makeUserSession())
        self.summary = previewSummary
        self.categorySummaries = categorySummaries
        self.recentReceipts = recentReceipts
        self.recentPurchases = recentPurchases
        self.templates = templates
        self.lastImportResult = lastImportResult
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.allImports = recentReceipts
        self.allLineItems = recentPurchases.map(\.lineItem)
        self.hasLoaded = true
    }
}
