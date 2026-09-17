import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class GroceryListDetailViewModel {
    private(set) var activeItems: [UserGroceryListItem] = []
    private(set) var purchasedItems: [UserGroceryListItem] = []
    private(set) var removedItems: [UserGroceryListItem] = []
    private(set) var catalogSuggestions: [ProductCatalogItem] = Array(SeededProductCatalog.items.prefix(6))
    private(set) var isLoading = false
    var latestSuggestion: GroceryReactivationSuggestion?
    var errorMessage: String?

    private let userId: String?
    private let listId: String
    private let repository: SmartGroceryRepository
    private let service: SmartGroceryService

    @ObservationIgnored
    private nonisolated(unsafe) var itemsListener: ListenerRegistration?
    private var allItems: [UserGroceryListItem] = []
    private var hasLoaded = false
    private var isRefreshingCatalog = false

    init(list: UserGroceryList, userSession: UserSession, repository: SmartGroceryRepository = SmartGroceryRepository()) {
        self.userId = userSession.currentUserId
        self.listId = list.id
        self.repository = repository
        self.service = SmartGroceryService(repository: repository)
    }

    deinit {
        itemsListener?.remove()
    }

    var totalVisibleItems: Int {
        activeItems.count + purchasedItems.count + removedItems.count
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let userId, !userId.isEmpty else {
            errorMessage = "Non riesco a capire quale account usare per Smart Grocery."
            return
        }

        isLoading = true
        let catalog = await service.prepareCatalog()
        catalogSuggestions = Array(catalog.prefix(6))

        itemsListener?.remove()
        itemsListener = repository.observeItems(for: listId, userId: userId) { [weak self] result in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                switch result {
                case .success(let items):
                    self.allItems = items
                    self.refreshSections()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare gli articoli della lista. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func previewMatch(for rawInputText: String) -> GroceryCatalogMatch? {
        service.match(rawInputText: rawInputText)
    }

    @discardableResult
    func addItem(draft: GroceryItemDraft) async -> Bool {
        guard let userId else {
            errorMessage = "Account non disponibile."
            return false
        }

        do {
            let result = try await service.createItemResult(listId: listId, userId: userId, draft: draft)
            latestSuggestion = result.suggestion
            return true
        } catch {
            errorMessage = "Non riesco ad aggiungere l'articolo. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func updateItem(_ item: UserGroceryListItem, draft: GroceryItemDraft) async -> Bool {
        do {
            _ = try await service.updateItem(item, with: draft)
            return true
        } catch {
            errorMessage = "Non riesco ad aggiornare l'articolo. \(error.localizedDescription)"
            return false
        }
    }

    func togglePurchased(_ item: UserGroceryListItem) {
        let newStatus: GroceryItemStatus = item.status == .purchased ? .active : .purchased
        _Concurrency.Task {
            do {
                _ = try await service.setStatus(for: item, status: newStatus)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Non riesco a cambiare lo stato dell'articolo. \(error.localizedDescription)"
                }
            }
        }
    }

    func removeItem(_ item: UserGroceryListItem) {
        _Concurrency.Task {
            do {
                _ = try await service.setStatus(for: item, status: .removed)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Non riesco a rimuovere l'articolo. \(error.localizedDescription)"
                }
            }
        }
    }

    func restoreItem(_ item: UserGroceryListItem) {
        _Concurrency.Task {
            do {
                _ = try await service.setStatus(for: item, status: .active)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Non riesco a ripristinare l'articolo. \(error.localizedDescription)"
                }
            }
        }
    }

    func adjustQuantity(for item: UserGroceryListItem, delta: Double) {
        _Concurrency.Task {
            do {
                _ = try await service.updateQuantity(for: item, delta: delta)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Non riesco ad aggiornare la quantita. \(error.localizedDescription)"
                }
            }
        }
    }

    func clearLatestSuggestion() {
        latestSuggestion = nil
    }

    private func refreshSections() {
        activeItems = sortedItems(allItems.filter { $0.status == .active })
        purchasedItems = sortedItems(allItems.filter { $0.status == .purchased })
        removedItems = sortedItems(allItems.filter { $0.status == .removed })

        let suggestions = service.makeUpcomingSuggestions(from: allItems, limit: 6)
        catalogSuggestions = suggestions.isEmpty ? Array(service.catalogCache.prefix(6)) : suggestions
        refreshCatalogIfNeeded()
        isLoading = false
    }

    private func refreshCatalogIfNeeded() {
        guard !isRefreshingCatalog else { return }

        let knownCatalogIds = Set(service.catalogCache.map(\.id))
        let missingCatalogIds = Set(allItems.compactMap(\.productCatalogId)).subtracting(knownCatalogIds)
        guard !missingCatalogIds.isEmpty else {
            return
        }

        isRefreshingCatalog = true
        _Concurrency.Task { @MainActor in
            let catalog = await service.prepareCatalog()
            let suggestions = service.makeUpcomingSuggestions(from: allItems, limit: 6)
            catalogSuggestions = suggestions.isEmpty ? Array(catalog.prefix(6)) : suggestions
            isRefreshingCatalog = false
        }
    }

    private func sortedItems(_ items: [UserGroceryListItem]) -> [UserGroceryListItem] {
        items.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

extension GroceryListDetailViewModel {
    convenience init(
        previewActiveItems: [UserGroceryListItem],
        purchasedItems: [UserGroceryListItem],
        removedItems: [UserGroceryListItem],
        catalogSuggestions: [ProductCatalogItem],
        latestSuggestion: GroceryReactivationSuggestion? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(list: PreviewSupport.defaultList, userSession: PreviewSupport.makeUserSession())
        self.activeItems = previewActiveItems
        self.purchasedItems = purchasedItems
        self.removedItems = removedItems
        self.catalogSuggestions = catalogSuggestions
        self.latestSuggestion = latestSuggestion
        self.errorMessage = errorMessage
        self.isLoading = isLoading
        self.allItems = previewActiveItems + purchasedItems + removedItems
        self.hasLoaded = true
    }
}
