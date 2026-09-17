import Foundation
import FirebaseFirestore
import Observation

/// Cosa mostrare nell'elenco ricette.
enum RecipeFilter: String, CaseIterable, Identifiable, Hashable {
    /// Hai tutto il necessario.
    case canCook
    /// Ti manca poco.
    case almost
    case all

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .canCook:
            return "Puoi cucinare"
        case .almost:
            return "Ti manca poco"
        case .all:
            return "Tutte"
        }
    }
}

@MainActor
@Observable
final class RecipeHomeViewModel {
    private(set) var availabilities: [RecipeAvailability] = []
    private(set) var pantryItems: [PantryItem] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    var searchText = ""
    var filter: RecipeFilter = .canCook
    var courseFilter: RecipeCourse?

    /// Quanti ingredienti mancanti si tollerano in "Ti manca poco".
    static let almostThreshold = 2

    private let userId: String?
    private let service: RecipeService
    private let pantryRepository: PantryRepository
    private let matcher = RecipeMatcher()

    @ObservationIgnored private var catalog: RecipeCatalog = .empty
    @ObservationIgnored private nonisolated(unsafe) var pantryListener: ListenerRegistration?

    // `RecipeService` è isolato al main actor: va costruito nel corpo dell'init,
    // non in un valore di default (che verrebbe valutato dal chiamante).
    init(
        userId: String?,
        service: RecipeService? = nil,
        pantryRepository: PantryRepository = PantryRepository()
    ) {
        self.userId = userId
        self.service = service ?? RecipeService()
        self.pantryRepository = pantryRepository
    }

    deinit {
        pantryListener?.remove()
    }

    // MARK: - Caricamento

    func start() async {
        guard catalog.canonical.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        catalog = await service.loadCatalog(userId: userId)

        if catalog.canonical.isEmpty {
            errorMessage = RecipeSeedLoader.LoaderError.resourceMissing.errorDescription
        }

        observePantry()
        recompute()
    }

    func retry() async {
        catalog = .empty
        pantryListener?.remove()
        pantryListener = nil
        await start()
    }

    private func observePantry() {
        guard let userId, pantryListener == nil else {
            recompute()
            return
        }

        pantryListener = pantryRepository.observeItems(for: userId) { [weak self] result in
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }

                if case .success(let items) = result {
                    self.pantryItems = items
                    self.recompute()
                }
            }
        }
    }

    private func recompute() {
        availabilities = matcher.rank(recipes: catalog.visibleRecipes, pantry: pantryItems)
    }

    // MARK: - Derivati

    var filteredAvailabilities: [RecipeAvailability] {
        var result = availabilities

        switch filter {
        case .canCook:
            result = result.filter(\.canCook)
        case .almost:
            result = result.filter { !$0.canCook && $0.missingIngredients.count <= Self.almostThreshold }
        case .all:
            break
        }

        if let courseFilter {
            result = result.filter { $0.recipe.course == courseFilter }
        }

        let query = searchText.trimmed
        if !query.isEmpty {
            result = result.filter { availability in
                availability.recipe.searchableCorpus.contains { $0.localizedStandardContains(query) }
            }
        }

        return result
    }

    /// Ricette che consumano qualcosa in scadenza: il motivo per cui l'app parla
    /// per prima, invece di aspettare che l'utente chieda.
    var rescueSuggestions: [RecipeAvailability] {
        availabilities
            .filter { $0.canCook && !$0.expiringItemsUsed.isEmpty }
            .prefix(3)
            .map { $0 }
    }

    var canCookCount: Int {
        availabilities.filter(\.canCook).count
    }

    var hasPantryData: Bool {
        !pantryItems.isEmpty
    }

    func availability(for recipeId: String) -> RecipeAvailability? {
        availabilities.first { $0.recipe.id == recipeId }
    }

    // MARK: - Azioni

    func addMissingToShoppingList(_ availability: RecipeAvailability) async {
        guard let userId else {
            errorMessage = RecipeError.notAuthenticated.errorDescription
            return
        }

        do {
            let added = try await service.addMissingToShoppingList(availability, userId: userId)
            infoMessage = String(
                localized: "recipes.addedToList",
                defaultValue: "\(added) ingredienti aggiunti alla lista."
            )
        } catch {
            errorMessage = RecipeError.persistenceFailed.errorDescription
        }
    }

    func markCooked(_ availability: RecipeAvailability) async {
        do {
            let consumed = try await service.consumePantry(for: availability, pantry: pantryItems)
            infoMessage = consumed > 0
                ? String(localized: "recipes.pantryUpdated", defaultValue: "Dispensa aggiornata: \(consumed) prodotti scalati.")
                : String(localized: "recipes.pantryUnchanged", defaultValue: "Niente da scalare in dispensa.")
        } catch {
            errorMessage = PantryError.persistenceFailed.errorDescription
        }
    }

    func makeVariant(of recipe: Recipe) -> Recipe? {
        guard let userId else {
            errorMessage = RecipeError.notAuthenticated.errorDescription
            return nil
        }

        return service.makeVariant(of: recipe, ownerId: userId)
    }

    func save(_ recipe: Recipe) async {
        do {
            try await service.save(recipe)
            catalog = await service.loadCatalog(userId: userId)
            recompute()
            infoMessage = String(localized: "recipes.variantSaved", defaultValue: "Variante salvata.")
        } catch let error as RecipeError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = RecipeError.persistenceFailed.errorDescription
        }
    }

    func delete(_ recipe: Recipe) async {
        do {
            try await service.delete(recipe)
            catalog = await service.loadCatalog(userId: userId)
            recompute()
        } catch let error as RecipeError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = RecipeError.persistenceFailed.errorDescription
        }
    }

    func variants(of recipe: Recipe) -> [Recipe] {
        catalog.variants(of: recipe.parentId ?? recipe.id)
    }

    func parentRecipe(of recipe: Recipe) -> Recipe? {
        recipe.parentId.flatMap { catalog.recipe(withId: $0) }
    }
}
