import XCTest
@testable import NeatNest

final class RecipeCatalogTests: XCTestCase {
    private var seedRecipes: [Recipe] = []

    override func setUpWithError() throws {
        seedRecipes = try RecipeSeedLoader.loadCanonicalRecipes(bundle: Bundle(for: Self.self))
    }

    func testSeedIsLoadedAndWellFormed() throws {
        XCTAssertGreaterThanOrEqual(seedRecipes.count, 30)

        for recipe in seedRecipes {
            XCTAssertFalse(recipe.displayTitle.isEmpty, "Ricetta senza titolo: \(recipe.id)")
            XCTAssertFalse(recipe.ingredients.isEmpty, "Ricetta senza ingredienti: \(recipe.id)")
            XCTAssertFalse(recipe.steps.isEmpty, "Ricetta senza procedimento: \(recipe.id)")
            XCTAssertEqual(recipe.visibility, .canonical)
            XCTAssertGreaterThan(recipe.servings, 0)

            for ingredient in recipe.ingredients {
                XCTAssertFalse(ingredient.matchTokens.isEmpty, "Ingrediente senza token: \(recipe.id)")
                XCTAssertFalse(ingredient.displayName.isEmpty)
            }
        }
    }

    func testRecipeIdsAreUnique() {
        let ids = seedRecipes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryRecipeIsReachableFromAPlausiblePantry() {
        // Nessuna ricetta deve essere irraggiungibile per un errore di token:
        // con i suoi stessi ingredienti in dispensa, deve risultare cucinabile.
        let matcher = RecipeMatcher()

        for recipe in seedRecipes {
            let pantry = recipe.requiredIngredients.map { ingredient in
                PantryItem(userId: "u1", name: ingredient.name, quantity: PantryQuantity(value: 999, unit: .piece))
            }

            XCTAssertTrue(
                matcher.availability(for: recipe, pantry: pantry).canCook,
                "\(recipe.displayTitle) non risulta cucinabile nemmeno con i suoi ingredienti"
            )
        }
    }

    func testScalingServingsScalesQuantities() throws {
        let recipe = try XCTUnwrap(seedRecipes.first { $0.servings == 2 && $0.ingredients.contains { $0.quantity != nil } })
        let doubled = recipe.scaled(toServings: 4)

        XCTAssertEqual(doubled.servings, 4)
        for (original, scaled) in zip(recipe.ingredients, doubled.ingredients) {
            guard let originalQuantity = original.quantity, let scaledQuantity = scaled.quantity else { continue }
            XCTAssertEqual(scaledQuantity, originalQuantity * 2, accuracy: 0.001)
        }
    }

    func testVariantPointsAtTheParentAndBelongsToTheUser() throws {
        let mother = try XCTUnwrap(seedRecipes.first)
        let variant = mother.makeVariant(ownerId: "u1")

        XCTAssertEqual(variant.parentId, mother.id)
        XCTAssertEqual(variant.ownerId, "u1")
        XCTAssertEqual(variant.visibility, .household)
        XCTAssertTrue(variant.visibility.isEditable)
        XCTAssertNotEqual(variant.id, mother.id)
    }

    func testVariantOfAVariantStillPointsAtTheOriginalMother() throws {
        let mother = try XCTUnwrap(seedRecipes.first)
        let variant = mother.makeVariant(ownerId: "u1")
        let grandchild = variant.makeVariant(ownerId: "u2")

        XCTAssertEqual(grandchild.parentId, mother.id, "Le varianti non formano catene: puntano tutte alla madre")
    }

    func testUserVariantReplacesItsParentInTheList() throws {
        let mother = try XCTUnwrap(seedRecipes.first)
        let variant = mother.makeVariant(ownerId: "u1")
        let catalog = RecipeCatalog(canonical: seedRecipes, userRecipes: [variant])

        let visibleIds = catalog.visibleRecipes.map(\.id)
        XCTAssertFalse(visibleIds.contains(mother.id), "La madre sparisce dall'elenco quando hai la tua variante")
        XCTAssertTrue(visibleIds.contains(variant.id))
        XCTAssertEqual(catalog.visibleRecipes.count, seedRecipes.count)
    }

    func testFirestoreRoundTrip() throws {
        let original = try XCTUnwrap(seedRecipes.first).makeVariant(ownerId: "u1")
        let decoded = try XCTUnwrap(Recipe.fromDocument(id: original.id, data: original.documentData))

        XCTAssertEqual(decoded.displayTitle, original.displayTitle)
        XCTAssertEqual(decoded.ingredients.count, original.ingredients.count)
        XCTAssertEqual(decoded.steps.count, original.steps.count)
        XCTAssertEqual(decoded.parentId, original.parentId)
        XCTAssertEqual(decoded.visibility, .household)
    }
}
