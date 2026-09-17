import Foundation

/// Stato di un ingrediente rispetto a ciò che c'è in dispensa.
enum RecipeIngredientStatus: Hashable, Sendable {
    /// C'è, e in quantità sufficiente (o la quantità non è confrontabile).
    case available
    /// C'è ma non basta.
    case partial(have: PantryQuantity, need: PantryQuantity)
    /// Non c'è, e serve.
    case missing
    /// Non c'è, ma è facoltativo.
    case optionalMissing

    var isBlocking: Bool {
        switch self {
        case .missing, .partial:
            return true
        case .available, .optionalMissing:
            return false
        }
    }
}

struct RecipeIngredientMatch: Identifiable, Hashable, Sendable {
    var id: String { ingredient.id }
    let ingredient: RecipeIngredient
    let status: RecipeIngredientStatus
    let matchedItemIds: [String]
}

/// Quanto una ricetta è fattibile adesso, con questa dispensa.
struct RecipeAvailability: Identifiable, Hashable, Sendable {
    var id: String { recipe.id }
    let recipe: Recipe
    let matches: [RecipeIngredientMatch]
    /// Prodotti in scadenza che questa ricetta consuma.
    let expiringItemsUsed: [PantryItem]

    var blockingMatches: [RecipeIngredientMatch] {
        matches.filter { $0.status.isBlocking }
    }

    var missingIngredients: [RecipeIngredient] {
        blockingMatches.map(\.ingredient)
    }

    var canCook: Bool {
        blockingMatches.isEmpty
    }

    /// Quota di ingredienti necessari che hai già, fra 0 e 1.
    var coverage: Double {
        let required = matches.filter { !$0.ingredient.isOptional }
        guard !required.isEmpty else { return 1 }

        let satisfied = required.filter { !$0.status.isBlocking }.count
        return Double(satisfied) / Double(required.count)
    }

    /// Ordina i suggerimenti: prima ciò che puoi fare, poi ciò che salva
    /// prodotti in scadenza, poi ciò a cui manca poco.
    var score: Double {
        var value = coverage * 100

        if canCook {
            value += 50
        }

        // Ogni prodotto in scadenza che la ricetta consuma vale più di un
        // ingrediente in più coperto: è il motivo per cui suggeriamo.
        value += Double(expiringItemsUsed.count) * 15

        if recipe.totalMinutes <= 20 {
            value += 5
        }

        return value
    }
}

/// Confronta ricette e dispensa.
///
/// Il match è per token normalizzati, non per identità di prodotto: in dispensa
/// c'è "Latte Arborea", la ricetta chiede "latte", e devono incontrarsi.
struct RecipeMatcher: Sendable {
    private let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func availability(for recipe: Recipe, pantry: [PantryItem]) -> RecipeAvailability {
        let index = pantry.map { item in
            (item: item, tokens: Set(RecipeTextNormalizer.tokens(from: item.displayName)))
        }

        var matches: [RecipeIngredientMatch] = []
        var expiringUsed: [String: PantryItem] = [:]

        for ingredient in recipe.ingredients {
            let wanted = Set(ingredient.allMatchTokens.map(RecipeTextNormalizer.normalize))
            let found = index.filter { !$0.tokens.isDisjoint(with: wanted) }

            guard !found.isEmpty else {
                matches.append(
                    RecipeIngredientMatch(
                        ingredient: ingredient,
                        status: ingredient.isOptional ? .optionalMissing : .missing,
                        matchedItemIds: []
                    )
                )
                continue
            }

            for entry in found where entry.item.freshness(referenceDate: referenceDate).isActionable {
                expiringUsed[entry.item.id] = entry.item
            }

            matches.append(
                RecipeIngredientMatch(
                    ingredient: ingredient,
                    status: status(for: ingredient, matchedItems: found.map(\.item)),
                    matchedItemIds: found.map(\.item.id)
                )
            )
        }

        return RecipeAvailability(
            recipe: recipe,
            matches: matches,
            expiringItemsUsed: Array(expiringUsed.values)
        )
    }

    func rank(recipes: [Recipe], pantry: [PantryItem]) -> [RecipeAvailability] {
        recipes
            .map { availability(for: $0, pantry: pantry) }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.recipe.displayTitle.localizedStandardCompare(rhs.recipe.displayTitle) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
    }

    /// Le quantità si confrontano solo fra unità della stessa famiglia. Il sale
    /// "q.b." non ha quantità: basta che ci sia.
    private func status(for ingredient: RecipeIngredient, matchedItems: [PantryItem]) -> RecipeIngredientStatus {
        guard let neededValue = ingredient.quantity, let neededUnit = ingredient.unit else {
            return .available
        }

        let need = PantryQuantity(value: neededValue, unit: neededUnit)
        let comparable = matchedItems.filter { $0.quantity.unit.kind == neededUnit.kind }

        guard !comparable.isEmpty else {
            // Ho il prodotto ma non so confrontarlo (3 pezzi di burro vs 50 g):
            // meglio dirlo disponibile che bloccare la ricetta per un dubbio.
            return .available
        }

        let total = comparable.reduce(0.0) { $0 + $1.quantity.valueInBaseUnit }
        let have = PantryQuantity(value: total / neededUnit.baseUnitFactor, unit: neededUnit)

        return have.covers(need) ? .available : .partial(have: have, need: need)
    }
}
