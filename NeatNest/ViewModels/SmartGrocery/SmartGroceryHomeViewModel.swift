import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class SmartGroceryHomeViewModel {
    private(set) var listSummaries: [GroceryListSummary] = []
    private(set) var recentItems: [UserGroceryListItem] = []
    private(set) var upcomingSuggestions: [ProductCatalogItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let userId: String?
    private let repository: SmartGroceryRepository
    private let service: SmartGroceryService

    @ObservationIgnored
    private nonisolated(unsafe) var listsListener: ListenerRegistration?
    @ObservationIgnored
    private nonisolated(unsafe) var itemsListener: ListenerRegistration?
    private var allLists: [UserGroceryList] = []
    private var allItems: [UserGroceryListItem] = []
    private var hasLoaded = false

    init(userSession: UserSession, repository: SmartGroceryRepository = SmartGroceryRepository()) {
        self.userId = userSession.currentUserId
        self.repository = repository
        self.service = SmartGroceryService(repository: repository)
    }

    deinit {
        listsListener?.remove()
        itemsListener?.remove()
    }

    var defaultListSummary: GroceryListSummary? {
        listSummaries.first(where: { $0.list.isDefault }) ?? listSummaries.first
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let userId, !userId.isEmpty else {
            errorMessage = "Non riesco a capire quale account usare per Smart Grocery."
            return
        }

        isLoading = true
        upcomingSuggestions = await service.prepareCatalog()
        upcomingSuggestions = Array(upcomingSuggestions.prefix(6))

        do {
            _ = try await service.ensureDefaultList(for: userId)
        } catch {
            errorMessage = "Non riesco a preparare la lista principale. \(error.localizedDescription)"
        }

        startObserving(userId: userId)
    }

    private func startObserving(userId: String) {
        listsListener?.remove()
        itemsListener?.remove()

        listsListener = repository.observeLists(for: userId) { [weak self] result in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                switch result {
                case .success(let lists):
                    self.allLists = lists
                    self.refreshDerivedState()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare le liste. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }

        itemsListener = repository.observeAllItems(for: userId) { [weak self] result in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                switch result {
                case .success(let items):
                    self.allItems = items
                    self.refreshDerivedState()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare gli articoli. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshDerivedState() {
        listSummaries = service.buildListSummaries(lists: allLists, items: allItems)
        recentItems = Array(
            allItems
                .filter { $0.status != .removed }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(5)
        )

        let suggestions = service.makeUpcomingSuggestions(from: allItems, limit: 6)
        upcomingSuggestions = suggestions.isEmpty ? Array(service.catalogCache.prefix(6)) : suggestions
        isLoading = false
    }
}

extension SmartGroceryHomeViewModel {
    convenience init(
        previewListSummaries: [GroceryListSummary],
        recentItems: [UserGroceryListItem],
        upcomingSuggestions: [ProductCatalogItem],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(userSession: PreviewSupport.makeUserSession())
        self.listSummaries = previewListSummaries
        self.recentItems = recentItems
        self.upcomingSuggestions = upcomingSuggestions
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.allLists = previewListSummaries.map(\.list)
        self.allItems = recentItems
        self.hasLoaded = true
    }
}
