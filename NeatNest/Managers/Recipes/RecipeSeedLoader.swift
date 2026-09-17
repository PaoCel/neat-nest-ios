import Foundation

/// Carica il canone di ricette che viaggia dentro l'app.
///
/// Il canone è un file JSON nel bundle, non una chiamata di rete: le ricette di
/// base ci sono anche senza account, senza connessione e senza chiavi API.
/// Firestore serve solo per le varianti dell'utente e per eventuali ricette
/// aggiunte dopo la pubblicazione.
enum RecipeSeedLoader {
    enum LoaderError: Error, LocalizedError {
        case resourceMissing
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .resourceMissing:
                return String(
                    localized: "recipes.error.seedMissing",
                    defaultValue: "Il ricettario di base non è disponibile."
                )
            case .decodingFailed:
                return String(
                    localized: "recipes.error.seedDecoding",
                    defaultValue: "Il ricettario di base non è leggibile."
                )
            }
        }
    }

    static func loadCanonicalRecipes(bundle: Bundle = .main) throws -> [Recipe] {
        guard let url = bundle.url(forResource: "Recipes", withExtension: "json") else {
            throw LoaderError.resourceMissing
        }

        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(SeedCatalog.self, from: data)
            return catalog.recipes.map { $0.makeRecipe() }
        } catch {
            throw LoaderError.decodingFailed
        }
    }
}

// MARK: - Forma del JSON

private extension RecipeSeedLoader {
    struct SeedCatalog: Decodable {
        let version: Int
        let recipes: [SeedRecipe]
    }

    struct SeedRecipe: Decodable {
        let id: String
        let title: [String: String]
        let summary: [String: String]?
        let servings: Int
        let prepMinutes: Int
        let cookMinutes: Int
        let difficulty: String
        let course: String
        let tags: [String]
        let ingredients: [SeedIngredient]
        let steps: [SeedStep]

        func makeRecipe() -> Recipe {
            Recipe(
                id: id,
                visibility: .canonical,
                title: LocalizedContent(title),
                summary: summary.map(LocalizedContent.init),
                servings: servings,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                difficulty: RecipeDifficulty(rawValue: difficulty) ?? .easy,
                course: RecipeCourse(rawValue: course) ?? .first,
                tags: tags,
                ingredients: ingredients.enumerated().map { index, seed in
                    seed.makeIngredient(id: "\(id)-ing-\(index)")
                },
                steps: steps.enumerated().map { index, seed in
                    seed.makeStep(id: "\(id)-step-\(index)")
                }
            )
        }
    }

    struct SeedIngredient: Decodable {
        let name: [String: String]
        let tokens: [String]
        let quantity: Double?
        let unit: String?
        let isOptional: Bool?
        let substituteTokens: [String]?
        let note: [String: String]?

        func makeIngredient(id: String) -> RecipeIngredient {
            RecipeIngredient(
                id: id,
                name: LocalizedContent(name),
                matchTokens: tokens,
                quantity: quantity,
                unit: unit.flatMap(PantryUnit.init(rawValue:)),
                isOptional: isOptional ?? false,
                substituteTokens: substituteTokens ?? [],
                note: note.map(LocalizedContent.init)
            )
        }
    }

    struct SeedStep: Decodable {
        let text: [String: String]
        let minutes: Int?

        func makeStep(id: String) -> RecipeStep {
            RecipeStep(id: id, text: LocalizedContent(text), minutes: minutes)
        }
    }
}
