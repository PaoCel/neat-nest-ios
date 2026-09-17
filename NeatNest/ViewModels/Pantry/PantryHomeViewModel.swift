import Foundation
import FirebaseFirestore
import Observation

/// Come raggruppare la dispensa a schermo.
enum PantryGrouping: String, CaseIterable, Identifiable, Hashable {
    case freshness
    case storage
    case category

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .freshness:
            return "Scadenza"
        case .storage:
            return "Posizione"
        case .category:
            return "Categoria"
        }
    }
}

/// Una sezione della lista dispensa.
struct PantrySection: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let items: [PantryItem]
}

@MainActor
@Observable
final class PantryHomeViewModel {
    private(set) var items: [PantryItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var searchText = ""
    var grouping: PantryGrouping = .freshness
    var storageFilter: PantryStorage?

    private let service: PantryService
    private let repository: PantryRepository
    private let expenseRepository: GroceryExpenseRepository
    private let groceryService: SmartGroceryService
    private let predictor = RepurchasePredictor()
    private let userId: String

    private(set) var repurchaseSuggestions: [RepurchaseSuggestion] = []
    /// Prodotti già rimandati in lista: non si ripropongono nella stessa sessione.
    @ObservationIgnored private var handledSuggestionKeys: Set<String> = []
    /// Fuori dall'osservazione: non è stato della UI, ed è l'unica cosa a cui
    /// `deinit` può accedere senza violare l'isolamento del main actor.
    @ObservationIgnored
    private nonisolated(unsafe) var listener: ListenerRegistration?

    init(
        userId: String,
        repository: PantryRepository = PantryRepository(),
        service: PantryService? = nil,
        expenseRepository: GroceryExpenseRepository = GroceryExpenseRepository(),
        groceryService: SmartGroceryService? = nil
    ) {
        self.userId = userId
        self.repository = repository
        self.service = service ?? PantryService(repository: repository)
        self.expenseRepository = expenseRepository
        self.groceryService = groceryService ?? SmartGroceryService()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Caricamento

    func start() {
        guard listener == nil else { return }

        isLoading = true
        errorMessage = nil

        listener = repository.observeItems(for: userId) { [weak self] result in
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }

                self.isLoading = false

                switch result {
                case .success(let items):
                    self.items = items
                    self.errorMessage = nil
                case .failure:
                    self.errorMessage = PantryError.persistenceFailed.errorDescription
                }
            }
        }
    }

    /// Ricostruisce le abitudini di riacquisto dallo storico scontrini.
    ///
    /// Gira in sottofondo: se fallisce, la dispensa funziona lo stesso senza
    /// suggerimenti. Non è un dato per cui valga la pena mostrare un errore.
    func loadRepurchaseSuggestions() async {
        do {
            async let receiptsTask = expenseRepository.fetchReceiptImports(for: userId)
            async let lineItemsTask = expenseRepository.fetchReceiptLineItems(for: userId)

            let (receipts, lineItems) = try await (receiptsTask, lineItemsTask)
            let dates = Dictionary(receipts.map { ($0.id, $0.purchaseDate) }, uniquingKeysWith: { first, _ in first })

            let events = RepurchasePredictor.purchaseEvents(from: lineItems, receiptDates: dates)
            let suggestions = predictor.suggestions(from: events, pantry: items)

            repurchaseSuggestions = suggestions.filter { !handledSuggestionKeys.contains($0.productKey) }
        } catch {
            repurchaseSuggestions = []
        }
    }

    /// Rimanda in lista della spesa qualcosa che di solito a quest'ora è finito.
    func addToShoppingList(_ suggestion: RepurchaseSuggestion) async {
        handledSuggestionKeys.insert(suggestion.productKey)
        repurchaseSuggestions.removeAll { $0.productKey == suggestion.productKey }

        await perform {
            let list = try await self.groceryService.ensureDefaultList(for: self.userId)
            _ = try await self.groceryService.createItem(
                listId: list.id,
                userId: self.userId,
                draft: GroceryItemDraft(
                    rawInputText: suggestion.displayName,
                    quantity: 1,
                    unit: nil,
                    notes: nil
                )
            )
        }
    }

    func dismissSuggestion(_ suggestion: RepurchaseSuggestion) {
        handledSuggestionKeys.insert(suggestion.productKey)
        repurchaseSuggestions.removeAll { $0.productKey == suggestion.productKey }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func retry() {
        stop()
        start()
    }

    // MARK: - Derivati

    var expiringSoonItems: [PantryItem] {
        items
            .filter { $0.freshness().isActionable }
            .sorted { lhs, rhs in
                (lhs.daysUntilExpiry() ?? .max) < (rhs.daysUntilExpiry() ?? .max)
            }
    }

    var filteredItems: [PantryItem] {
        var result = items

        if let storageFilter {
            result = result.filter { $0.storage == storageFilter }
        }

        let query = searchText.trimmed
        if !query.isEmpty {
            result = result.filter { item in
                item.name.searchableCorpus.contains { $0.localizedStandardContains(query) }
                    || (item.brand?.localizedStandardContains(query) ?? false)
            }
        }

        return result
    }

    var sections: [PantrySection] {
        switch grouping {
        case .freshness:
            return freshnessSections()
        case .storage:
            return storageSections()
        case .category:
            return categorySections()
        }
    }

    var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    // MARK: - Azioni

    func makeItem(
        name: String,
        quantity: PantryQuantity,
        category: GrocerySpendingCategory,
        storage: PantryStorage?,
        expiresAt: Date?,
        isOpened: Bool,
        notes: String?
    ) throws -> PantryItem {
        try service.makeItem(
            userId: userId,
            name: name,
            quantity: quantity,
            category: category,
            storage: storage,
            expiresAt: expiresAt,
            openedAt: isOpened ? Date() : nil,
            notes: notes?.trimmed.isEmpty == false ? notes?.trimmed : nil
        )
    }

    func save(_ item: PantryItem) async {
        await perform { try await self.service.add(item) }
    }

    func update(_ item: PantryItem) async {
        await perform { try await self.service.update(item) }
    }

    func delete(_ item: PantryItem) async {
        await perform { try await self.service.remove(item) }
    }

    func markOpened(_ item: PantryItem) async {
        await perform { _ = try await self.service.markOpened(item) }
    }

    /// Un tap dichiara quanto ne resta. Nessuno pesa niente.
    func setLevel(_ level: PantryLevel, for item: PantryItem) async {
        await perform { _ = try await self.service.setLevel(level, for: item) }
    }

    /// Prodotti su cui vale la pena chiedere "ancora buono?": stanno scadendo e
    /// non sappiamo davvero quanto ne resta.
    var itemsNeedingLevelCheck: [PantryItem] {
        items.filter { $0.freshness().isActionable && $0.isOpened && $0.isQuantityEstimated }
    }

    func consumeOne(_ item: PantryItem) async {
        let amount = PantryQuantity(value: 1, unit: item.quantity.unit)
        await perform { _ = try await self.service.consume(item, amount: amount) }
    }

    func consumeAll(_ item: PantryItem) async {
        await perform { _ = try await self.service.consume(item, amount: item.quantity) }
    }

    private func perform(_ work: @escaping () async throws -> Void) async {
        errorMessage = nil

        do {
            try await work()
        } catch let error as PantryError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = PantryError.persistenceFailed.errorDescription
        }
    }
}

// MARK: - Sezioni

private extension PantryHomeViewModel {
    func freshnessSections() -> [PantrySection] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            item.freshness().sortRank
        }

        return grouped
            .sorted { $0.key < $1.key }
            .compactMap { rank, items in
                guard let title = freshnessTitle(forRank: rank) else { return nil }

                return PantrySection(
                    id: "freshness-\(rank)",
                    title: title,
                    systemImage: freshnessIcon(forRank: rank),
                    items: items.sorted { lhs, rhs in
                        (lhs.daysUntilExpiry() ?? .max) < (rhs.daysUntilExpiry() ?? .max)
                    }
                )
            }
    }

    func freshnessTitle(forRank rank: Int) -> String? {
        switch rank {
        case 0:
            return String(localized: "pantry.section.expired", defaultValue: "Scaduti")
        case 1:
            return String(localized: "pantry.section.expiringSoon", defaultValue: "In scadenza")
        case 2:
            return String(localized: "pantry.section.fresh", defaultValue: "Freschi")
        case 3:
            return String(localized: "pantry.section.noExpiry", defaultValue: "Senza scadenza")
        default:
            return nil
        }
    }

    func freshnessIcon(forRank rank: Int) -> String {
        switch rank {
        case 0:
            return "exclamationmark.triangle.fill"
        case 1:
            return "clock.badge.exclamationmark"
        case 2:
            return "checkmark.circle"
        default:
            return "questionmark.circle"
        }
    }

    func storageSections() -> [PantrySection] {
        let grouped = Dictionary(grouping: filteredItems, by: \.storage)

        return PantryStorage.allCases.compactMap { storage in
            guard let items = grouped[storage], !items.isEmpty else { return nil }

            return PantrySection(
                id: "storage-\(storage.rawValue)",
                title: String(localized: storage.title),
                systemImage: storage.icon,
                items: items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            )
        }
    }

    func categorySections() -> [PantrySection] {
        let grouped = Dictionary(grouping: filteredItems, by: \.category)

        return GrocerySpendingCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }

            return PantrySection(
                id: "category-\(category.rawValue)",
                title: category.localizedTitle,
                systemImage: "tag",
                items: items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            )
        }
    }
}
