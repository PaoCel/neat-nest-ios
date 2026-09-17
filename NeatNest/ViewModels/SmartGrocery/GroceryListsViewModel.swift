import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class GroceryListsViewModel {
    private(set) var listSummaries: [GroceryListSummary] = []
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

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let userId, !userId.isEmpty else {
            errorMessage = "Non riesco a capire quale account usare per Smart Grocery."
            return
        }

        isLoading = true
        _ = await service.prepareCatalog()

        do {
            _ = try await service.ensureDefaultList(for: userId)
        } catch {
            errorMessage = "Non riesco a preparare la lista principale. \(error.localizedDescription)"
        }

        startObserving(userId: userId)
    }

    @discardableResult
    func createList(title: String) async -> Bool {
        guard let userId else {
            errorMessage = "Account non disponibile."
            return false
        }

        do {
            _ = try await service.createList(userId: userId, title: title)
            return true
        } catch {
            errorMessage = "Non riesco a creare la lista. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func renameList(_ list: UserGroceryList, title: String) async -> Bool {
        do {
            try await service.renameList(list, title: title)
            return true
        } catch {
            errorMessage = "Non riesco a rinominare la lista. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func deleteList(_ list: UserGroceryList) async -> Bool {
        guard !list.isDefault else {
            errorMessage = "La lista principale non puo essere eliminata in questa fase."
            return false
        }

        do {
            try await service.deleteList(list)
            return true
        } catch {
            errorMessage = "Non riesco a eliminare la lista. \(error.localizedDescription)"
            return false
        }
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
                    self.refreshSummaries()
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
                    self.refreshSummaries()
                case .failure(let error):
                    self.errorMessage = "Non riesco a caricare gli articoli. \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshSummaries() {
        listSummaries = service.buildListSummaries(lists: allLists, items: allItems)
        isLoading = false
    }
}

extension GroceryListsViewModel {
    convenience init(
        previewListSummaries: [GroceryListSummary],
        allItems: [UserGroceryListItem],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(userSession: PreviewSupport.makeUserSession())
        self.listSummaries = previewListSummaries
        self.allLists = previewListSummaries.map(\.list)
        self.allItems = allItems
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.hasLoaded = true
    }
}
