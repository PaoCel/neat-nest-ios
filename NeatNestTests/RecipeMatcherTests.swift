import XCTest
@testable import NeatNest

final class RecipeMatcherTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private lazy var matcher = RecipeMatcher(referenceDate: now)
    private let calendar = Calendar(identifier: .gregorian)

    func testBrandedPantryItemMatchesGenericIngredient() {
        // In dispensa c'è "Latte Arborea", la ricetta chiede "latte".
        let recipe = makeRecipe(ingredients: [ingredient("Latte", tokens: ["latte"])])
        let availability = matcher.availability(for: recipe, pantry: [pantryItem("Latte Arborea")])

        XCTAssertTrue(availability.canCook)
        XCTAssertEqual(availability.matches.first?.status, .available)
    }

    func testMissingRequiredIngredientBlocksTheRecipe() {
        let recipe = makeRecipe(ingredients: [
            ingredient("Latte", tokens: ["latte"]),
            ingredient("Guanciale", tokens: ["guanciale"])
        ])

        let availability = matcher.availability(for: recipe, pantry: [pantryItem("Latte Arborea")])

        XCTAssertFalse(availability.canCook)
        XCTAssertEqual(availability.missingIngredients.map(\.displayName), ["Guanciale"])
        XCTAssertEqual(availability.coverage, 0.5)
    }

    func testOptionalIngredientDoesNotBlock() {
        let recipe = makeRecipe(ingredients: [
            ingredient("Pasta", tokens: ["pasta"]),
            ingredient("Prezzemolo", tokens: ["prezzemolo"], isOptional: true)
        ])

        let availability = matcher.availability(for: recipe, pantry: [pantryItem("Pasta")])

        XCTAssertTrue(availability.canCook)
        XCTAssertEqual(availability.matches.last?.status, .optionalMissing)
        XCTAssertEqual(availability.coverage, 1)
    }

    func testSubstituteTokensRescueTheRecipe() {
        let recipe = makeRecipe(ingredients: [
            ingredient("Guanciale", tokens: ["guanciale"], substitutes: ["pancetta"])
        ])

        let availability = matcher.availability(for: recipe, pantry: [pantryItem("Pancetta affumicata")])

        XCTAssertTrue(availability.canCook)
    }

    func testNotEnoughQuantityIsPartialNotMissing() {
        let recipe = makeRecipe(ingredients: [
            ingredient("Farina", tokens: ["farina"], quantity: 500, unit: .gram)
        ])

        let pantry = [pantryItem("Farina", quantity: PantryQuantity(value: 200, unit: .gram))]
        let availability = matcher.availability(for: recipe, pantry: pantry)

        XCTAssertFalse(availability.canCook)
        guard case .partial(let have, let need) = availability.matches[0].status else {
            return XCTFail("Atteso stato parziale, trovato \(availability.matches[0].status)")
        }
        XCTAssertEqual(have.value, 200)
        XCTAssertEqual(need.value, 500)
    }

    func testQuantitiesSumAcrossMultiplePantryLines() {
        let recipe = makeRecipe(ingredients: [
            ingredient("Farina", tokens: ["farina"], quantity: 500, unit: .gram)
        ])

        let pantry = [
            pantryItem("Farina 00", quantity: PantryQuantity(value: 300, unit: .gram)),
            pantryItem("Farina integrale", quantity: PantryQuantity(value: 400, unit: .gram))
        ]

        XCTAssertTrue(matcher.availability(for: recipe, pantry: pantry).canCook)
    }

    func testIncomparableUnitsDoNotBlockTheRecipe() {
        // Ho "3 pezzi" di burro e la ricetta chiede 50 g: meglio proporla che
        // bloccarla per un dubbio di unità.
        let recipe = makeRecipe(ingredients: [
            ingredient("Burro", tokens: ["burro"], quantity: 50, unit: .gram)
        ])

        let pantry = [pantryItem("Burro", quantity: PantryQuantity(value: 3, unit: .piece))]

        XCTAssertTrue(matcher.availability(for: recipe, pantry: pantry).canCook)
    }

    func testExpiringIngredientsAreReported() {
        let recipe = makeRecipe(ingredients: [ingredient("Yogurt", tokens: ["yogurt"])])
        let expiring = pantryItem("Yogurt greco", expiresInDays: 1)

        let availability = matcher.availability(for: recipe, pantry: [expiring])

        XCTAssertEqual(availability.expiringItemsUsed.map(\.displayName), ["Yogurt greco"])
    }

    func testRankingPutsRescueRecipesFirst() {
        let plain = makeRecipe(title: "Pasta in bianco", ingredients: [ingredient("Pasta", tokens: ["pasta"])])
        let rescue = makeRecipe(title: "Yogurt e miele", ingredients: [ingredient("Yogurt", tokens: ["yogurt"])])

        let pantry = [
            pantryItem("Pasta", expiresInDays: 300),
            pantryItem("Yogurt greco", expiresInDays: 1)
        ]

        let ranked = matcher.rank(recipes: [plain, rescue], pantry: pantry)

        XCTAssertEqual(ranked.first?.recipe.displayTitle, "Yogurt e miele",
                       "Chi salva un prodotto in scadenza va suggerito per primo")
    }

    func testRankingPrefersWhatYouCanActuallyCook() {
        let ready = makeRecipe(title: "Pasta al pomodoro", ingredients: [ingredient("Pasta", tokens: ["pasta"])])
        let incomplete = makeRecipe(title: "Carbonara", ingredients: [
            ingredient("Pasta", tokens: ["pasta"]),
            ingredient("Guanciale", tokens: ["guanciale"])
        ])

        let ranked = matcher.rank(recipes: [incomplete, ready], pantry: [pantryItem("Pasta", expiresInDays: 300)])

        XCTAssertEqual(ranked.first?.recipe.displayTitle, "Pasta al pomodoro")
    }

    func testAccentsAndCaseDoNotBreakTheMatch() {
        let recipe = makeRecipe(ingredients: [ingredient("Caffè", tokens: ["caffe"])])
        XCTAssertTrue(matcher.availability(for: recipe, pantry: [pantryItem("CAFFÈ macinato")]).canCook)
    }

    // MARK: - Helpers

    private func makeRecipe(title: String = "Ricetta", ingredients: [RecipeIngredient]) -> Recipe {
        Recipe(title: LocalizedContent(source: title), ingredients: ingredients)
    }

    private func ingredient(
        _ name: String,
        tokens: [String],
        quantity: Double? = nil,
        unit: PantryUnit? = nil,
        isOptional: Bool = false,
        substitutes: [String] = []
    ) -> RecipeIngredient {
        RecipeIngredient(
            name: LocalizedContent(source: name),
            matchTokens: tokens,
            quantity: quantity,
            unit: unit,
            isOptional: isOptional,
            substituteTokens: substitutes
        )
    }

    private func pantryItem(
        _ name: String,
        quantity: PantryQuantity = PantryQuantity(value: 1, unit: .piece),
        expiresInDays: Int = 30
    ) -> PantryItem {
        PantryItem(
            userId: "u1",
            name: LocalizedContent(source: name),
            quantity: quantity,
            expiresAt: calendar.date(byAdding: .day, value: expiresInDays, to: now)
        )
    }
}
