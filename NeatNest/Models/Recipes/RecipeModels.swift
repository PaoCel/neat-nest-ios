import Foundation
import FirebaseFirestore

/// Chi può vedere una ricetta.
///
/// Il canone (`canonical`) è immutabile: quando l'utente modifica una ricetta
/// canonica non la sovrascrive, ne crea una variante `household` che punta alla
/// madre con `parentId`.
enum RecipeVisibility: String, CaseIterable, Identifiable, Hashable, Sendable {
    case canonical
    case household
    case personal

    var id: String { rawValue }

    var isEditable: Bool {
        self != .canonical
    }
}

enum RecipeDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy:
            return "Facile"
        case .medium:
            return "Media"
        case .hard:
            return "Impegnativa"
        }
    }
}

enum RecipeCourse: String, CaseIterable, Identifiable, Hashable, Sendable {
    case breakfast
    case starter
    case first
    case second
    case side
    case dessert
    case snack

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .breakfast:
            return "Colazione"
        case .starter:
            return "Antipasto"
        case .first:
            return "Primo"
        case .second:
            return "Secondo"
        case .side:
            return "Contorno"
        case .dessert:
            return "Dolce"
        case .snack:
            return "Spuntino"
        }
    }

    var icon: String {
        switch self {
        case .breakfast:
            return "cup.and.saucer"
        case .starter:
            return "leaf"
        case .first:
            return "fork.knife"
        case .second:
            return "flame"
        case .side:
            return "carrot"
        case .dessert:
            return "birthday.cake"
        case .snack:
            return "takeoutbag.and.cup.and.straw"
        }
    }
}

/// Un ingrediente di una ricetta.
///
/// `matchTokens` è ciò che permette il confronto con la dispensa: sono forme
/// normalizzate (minuscole, senza accenti) del nome e dei suoi sinonimi.
/// Il nome mostrato resta `name`, localizzabile.
struct RecipeIngredient: Identifiable, Hashable, Sendable {
    let id: String
    var name: LocalizedContent
    var matchTokens: [String]
    var quantity: Double?
    var unit: PantryUnit?
    /// Se manca, la ricetta si fa lo stesso.
    var isOptional: Bool
    /// Token di prodotti che possono sostituirlo (pancetta al posto del guanciale).
    var substituteTokens: [String]
    var note: LocalizedContent?

    init(
        id: String = UUID().uuidString,
        name: LocalizedContent,
        matchTokens: [String] = [],
        quantity: Double? = nil,
        unit: PantryUnit? = nil,
        isOptional: Bool = false,
        substituteTokens: [String] = [],
        note: LocalizedContent? = nil
    ) {
        self.id = id
        self.name = name
        self.matchTokens = matchTokens.isEmpty
            ? RecipeTextNormalizer.tokens(from: name.resolved(for: Locale(identifier: LocalizedContent.sourceLanguage)))
            : matchTokens
        self.quantity = quantity
        self.unit = unit
        self.isOptional = isOptional
        self.substituteTokens = substituteTokens
        self.note = note
    }

    var displayName: String {
        name.resolved()
    }

    /// "200 g" oppure niente, quando la quantità è a occhio.
    var quantityLabel: String? {
        guard let quantity, let unit else { return nil }
        return PantryQuantity(value: quantity, unit: unit).formatted()
    }

    var allMatchTokens: [String] {
        matchTokens + substituteTokens
    }
}

struct RecipeStep: Identifiable, Hashable, Sendable {
    let id: String
    var text: LocalizedContent
    /// Minuti di attesa in questo passo, per i timer.
    var minutes: Int?

    init(id: String = UUID().uuidString, text: LocalizedContent, minutes: Int? = nil) {
        self.id = id
        self.text = text
        self.minutes = minutes
    }

    var displayText: String {
        text.resolved()
    }
}

struct Recipe: Identifiable, Hashable, Sendable {
    let id: String
    /// La ricetta madre, se questa è una variante.
    var parentId: String?
    /// Chi l'ha creata. `nil` per il canone che arriva con l'app.
    var ownerId: String?
    var visibility: RecipeVisibility
    var title: LocalizedContent
    var summary: LocalizedContent?
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var difficulty: RecipeDifficulty
    var course: RecipeCourse
    var tags: [String]
    var ingredients: [RecipeIngredient]
    var steps: [RecipeStep]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        parentId: String? = nil,
        ownerId: String? = nil,
        visibility: RecipeVisibility = .canonical,
        title: LocalizedContent,
        summary: LocalizedContent? = nil,
        servings: Int = 2,
        prepMinutes: Int = 10,
        cookMinutes: Int = 15,
        difficulty: RecipeDifficulty = .easy,
        course: RecipeCourse = .first,
        tags: [String] = [],
        ingredients: [RecipeIngredient] = [],
        steps: [RecipeStep] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.parentId = parentId
        self.ownerId = ownerId
        self.visibility = visibility
        self.title = title
        self.summary = summary
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.difficulty = difficulty
        self.course = course
        self.tags = tags
        self.ingredients = ingredients
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        title.resolved()
    }

    var totalMinutes: Int {
        prepMinutes + cookMinutes
    }

    var isVariant: Bool {
        parentId != nil
    }

    var requiredIngredients: [RecipeIngredient] {
        ingredients.filter { !$0.isOptional }
    }

    var searchableCorpus: [String] {
        title.searchableCorpus + tags + ingredients.flatMap { $0.name.searchableCorpus }
    }

    /// Crea la variante personale di questa ricetta: stessa sostanza, madre
    /// tracciata, proprietà dell'utente.
    func makeVariant(ownerId: String, on date: Date = Date()) -> Recipe {
        Recipe(
            parentId: parentId ?? id,
            ownerId: ownerId,
            visibility: .household,
            title: title,
            summary: summary,
            servings: servings,
            prepMinutes: prepMinutes,
            cookMinutes: cookMinutes,
            difficulty: difficulty,
            course: course,
            tags: tags,
            ingredients: ingredients,
            steps: steps,
            createdAt: date,
            updatedAt: date
        )
    }

    /// Riscala le quantità su un numero di porzioni diverso.
    func scaled(toServings newServings: Int) -> Recipe {
        guard newServings > 0, servings > 0, newServings != servings else { return self }

        let factor = Double(newServings) / Double(servings)
        var copy = self
        copy.servings = newServings
        copy.ingredients = ingredients.map { ingredient in
            var scaled = ingredient
            scaled.quantity = ingredient.quantity.map { $0 * factor }
            return scaled
        }
        return copy
    }
}

/// Normalizza il testo per il confronto ingrediente ↔ dispensa.
enum RecipeTextNormalizer {
    /// Parole troppo comuni per distinguere un ingrediente da un altro.
    private static let stopwords: Set<String> = [
        "di", "da", "del", "della", "delle", "dei", "degli", "il", "lo", "la", "le", "gli",
        "un", "una", "uno", "e", "ed", "al", "alla", "allo", "con", "per", "in", "qb",
        "fresco", "fresca", "grande", "piccolo", "piccola",
        "of", "the", "a", "an", "and", "with", "fresh"
    ]

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
    }

    static func tokens(from text: String) -> [String] {
        normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmed }
            .filter { $0.count > 2 && !stopwords.contains($0) }
    }
}

// MARK: - Firestore

extension Recipe {
    static func fromDocument(id: String, data: [String: Any]) -> Recipe? {
        guard let title = LocalizedContent.decode(data["title"]) else { return nil }

        let createdAt = groceryDateValue(from: data["createdAt"]) ?? Date()

        return Recipe(
            id: id,
            parentId: data["parentId"] as? String,
            ownerId: data["ownerId"] as? String,
            visibility: RecipeVisibility(rawValue: data["visibility"] as? String ?? "") ?? .canonical,
            title: title,
            summary: LocalizedContent.decode(data["summary"]),
            servings: data["servings"] as? Int ?? 2,
            prepMinutes: data["prepMinutes"] as? Int ?? 0,
            cookMinutes: data["cookMinutes"] as? Int ?? 0,
            difficulty: RecipeDifficulty(rawValue: data["difficulty"] as? String ?? "") ?? .easy,
            course: RecipeCourse(rawValue: data["course"] as? String ?? "") ?? .first,
            tags: groceryStringArray(from: data["tags"]),
            ingredients: (data["ingredients"] as? [[String: Any]] ?? []).compactMap(RecipeIngredient.fromDocument),
            steps: (data["steps"] as? [[String: Any]] ?? []).compactMap(RecipeStep.fromDocument),
            createdAt: createdAt,
            updatedAt: groceryDateValue(from: data["updatedAt"]) ?? createdAt
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = [
            "visibility": visibility.rawValue,
            "title": title.documentValue,
            "servings": servings,
            "prepMinutes": prepMinutes,
            "cookMinutes": cookMinutes,
            "difficulty": difficulty.rawValue,
            "course": course.rawValue,
            "tags": tags,
            "ingredients": ingredients.map(\.documentData),
            "steps": steps.map(\.documentData),
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let parentId { data["parentId"] = parentId }
        if let ownerId { data["ownerId"] = ownerId }
        if let summary { data["summary"] = summary.documentValue }

        return data
    }
}

extension RecipeIngredient {
    static func fromDocument(_ data: [String: Any]) -> RecipeIngredient? {
        guard let name = LocalizedContent.decode(data["name"]) else { return nil }

        return RecipeIngredient(
            id: data["id"] as? String ?? UUID().uuidString,
            name: name,
            matchTokens: groceryStringArray(from: data["matchTokens"]),
            quantity: data["quantity"] as? Double,
            unit: (data["unit"] as? String).flatMap(PantryUnit.init(rawValue:)),
            isOptional: data["isOptional"] as? Bool ?? false,
            substituteTokens: groceryStringArray(from: data["substituteTokens"]),
            note: LocalizedContent.decode(data["note"])
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name.documentValue,
            "matchTokens": matchTokens,
            "isOptional": isOptional,
            "substituteTokens": substituteTokens
        ]

        if let quantity { data["quantity"] = quantity }
        if let unit { data["unit"] = unit.rawValue }
        if let note { data["note"] = note.documentValue }

        return data
    }
}

extension RecipeStep {
    static func fromDocument(_ data: [String: Any]) -> RecipeStep? {
        guard let text = LocalizedContent.decode(data["text"]) else { return nil }

        return RecipeStep(
            id: data["id"] as? String ?? UUID().uuidString,
            text: text,
            minutes: data["minutes"] as? Int
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = ["id": id, "text": text.documentValue]
        if let minutes { data["minutes"] = minutes }
        return data
    }
}
