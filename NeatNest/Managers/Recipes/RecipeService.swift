import Foundation

/// Il ricettario completo visto dall'utente.
struct RecipeCatalog: Sendable {
    var canonical: [Recipe]
    var userRecipes: [Recipe]

    /// Il canone meno le ricette di cui l'utente ha già una variante: se hai
    /// riscritto la carbonara, in lista vuoi la tua, non entrambe.
    var visibleRecipes: [Recipe] {
        let overriddenParentIds = Set(userRecipes.compactMap(\.parentId))
        return canonical.filter { !overriddenParentIds.contains($0.id) } + userRecipes
    }

    func variants(of recipeId: String) -> [Recipe] {
        userRecipes.filter { $0.parentId == recipeId }
    }

    func recipe(withId id: String) -> Recipe? {
        userRecipes.first { $0.id == id } ?? canonical.first { $0.id == id }
    }

    static let empty = RecipeCatalog(canonical: [], userRecipes: [])
}

/// Logica di dominio delle ricette: caricare il catalogo, creare varianti,
/// mandare gli ingredienti mancanti in lista spesa, scalare la dispensa dopo
/// aver cucinato.
///
/// Isolato al main actor perché si appoggia a `SmartGroceryService`, che lo è
/// già: il ponte con la lista della spesa passa da lì.
@MainActor
final class RecipeService {
    private let repository: RecipeRepository
    private let pantryService: PantryService
    private let groceryService: SmartGroceryService

    // `SmartGroceryService` è isolato al main actor e non può essere costruito
    // in un valore di default, che viene valutato nel contesto del chiamante.
    init(
        repository: RecipeRepository = RecipeRepository(),
        pantryService: PantryService = PantryService(),
        groceryService: SmartGroceryService? = nil
    ) {
        self.repository = repository
        self.pantryService = pantryService
        self.groceryService = groceryService ?? SmartGroceryService()
    }

    // MARK: - Catalogo

    /// Il canone del bundle è la base; l'overlay Firestore e le varianti
    /// dell'utente si aggiungono se disponibili. Un errore di rete non deve
    /// lasciare l'utente senza ricette.
    func loadCatalog(userId: String?) async -> RecipeCatalog {
        let bundled = (try? RecipeSeedLoader.loadCanonicalRecipes()) ?? []

        let overlay = (try? await repository.fetchCanonicalOverlay()) ?? []

        var userRecipes: [Recipe] = []
        if let userId {
            userRecipes = (try? await repository.fetchUserRecipes(for: userId)) ?? []
        }

        var canonicalById: [String: Recipe] = [:]
        for recipe in bundled {
            canonicalById[recipe.id] = recipe
        }
        // L'overlay vince sul bundle: permette di correggere una ricetta senza
        // pubblicare una nuova versione dell'app.
        for recipe in overlay {
            canonicalById[recipe.id] = recipe
        }

        return RecipeCatalog(canonical: Array(canonicalById.values), userRecipes: userRecipes)
    }

    // MARK: - Varianti

    func makeVariant(of recipe: Recipe, ownerId: String) -> Recipe {
        recipe.makeVariant(ownerId: ownerId)
    }

    func save(_ recipe: Recipe) async throws {
        guard !recipe.displayTitle.trimmed.isEmpty else { throw RecipeError.emptyTitle }

        var updated = recipe
        updated.updatedAt = Date()
        try await repository.save(updated)
    }

    func delete(_ recipe: Recipe) async throws {
        guard recipe.visibility.isEditable else { throw RecipeError.canonicalNotEditable }
        try await repository.delete(recipeId: recipe.id)
    }

    // MARK: - Ponte con la lista della spesa

    /// Manda in lista quello che manca. Restituisce quanti articoli ha aggiunto.
    @discardableResult
    func addMissingToShoppingList(
        _ availability: RecipeAvailability,
        userId: String
    ) async throws -> Int {
        let missing = availability.blockingMatches
        guard !missing.isEmpty else { return 0 }

        let list = try await groceryService.ensureDefaultList(for: userId)

        var added = 0
        for match in missing {
            let quantity = missingQuantity(for: match)

            let draft = GroceryItemDraft(
                rawInputText: match.ingredient.displayName,
                quantity: quantity.value,
                unit: quantity.unitLabel,
                notes: String(
                    localized: "recipes.shoppingNote",
                    defaultValue: "Per: \(availability.recipe.displayTitle)"
                )
            )

            _ = try await groceryService.createItem(listId: list.id, userId: userId, draft: draft)
            added += 1
        }

        return added
    }

    // MARK: - Dopo aver cucinato

    /// Scala dalla dispensa quello che la ricetta ha consumato.
    ///
    /// Tocca solo gli ingredienti con una quantità confrontabile: per il sale
    /// "q.b." non c'è niente da sottrarre.
    @discardableResult
    func consumePantry(for availability: RecipeAvailability, pantry: [PantryItem]) async throws -> Int {
        let itemsById = Dictionary(uniqueKeysWithValues: pantry.map { ($0.id, $0) })
        var consumed = 0

        for match in availability.matches {
            guard case .available = match.status,
                  let quantity = match.ingredient.quantity,
                  let unit = match.ingredient.unit else {
                continue
            }

            var remaining = PantryQuantity(value: quantity, unit: unit)

            for itemId in match.matchedItemIds {
                guard let item = itemsById[itemId], !remaining.isEmpty else { continue }
                guard item.quantity.unit.kind == unit.kind else { continue }

                let take = min(item.quantity.valueInBaseUnit, remaining.valueInBaseUnit)
                guard take > 0 else { continue }

                let takeQuantity = PantryQuantity(value: take / item.quantity.unit.baseUnitFactor, unit: item.quantity.unit)
                _ = try await pantryService.consume(item, amount: takeQuantity)
                consumed += 1

                remaining = PantryQuantity(
                    value: (remaining.valueInBaseUnit - take) / unit.baseUnitFactor,
                    unit: unit
                )
            }
        }

        return consumed
    }

    /// Quanto manca davvero: se ne hai metà, in lista va solo la metà mancante.
    private func missingQuantity(for match: RecipeIngredientMatch) -> PantryQuantity {
        switch match.status {
        case .partial(let have, let need):
            let delta = max(0, need.valueInBaseUnit - have.valueInBaseUnit)
            return PantryQuantity(value: delta / need.unit.baseUnitFactor, unit: need.unit)
        default:
            if let quantity = match.ingredient.quantity, let unit = match.ingredient.unit {
                return PantryQuantity(value: quantity, unit: unit)
            }
            return .single
        }
    }
}

private extension PantryQuantity {
    /// Etichetta breve per la lista della spesa, che memorizza l'unità come stringa.
    var unitLabel: String? {
        switch unit.kind {
        case .count:
            return nil
        default:
            return unit.rawValue
        }
    }
}
