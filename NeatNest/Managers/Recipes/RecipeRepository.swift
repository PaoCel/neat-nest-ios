import Foundation
import FirebaseFirestore

enum RecipeError: Error, LocalizedError {
    case notAuthenticated
    case canonicalNotEditable
    case emptyTitle
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "recipes.error.notAuthenticated", defaultValue: "Accedi per salvare le tue varianti.")
        case .canonicalNotEditable:
            return String(
                localized: "recipes.error.canonicalNotEditable",
                defaultValue: "Le ricette di base non si modificano: creane una variante."
            )
        case .emptyTitle:
            return String(localized: "recipes.error.emptyTitle", defaultValue: "Dai un titolo alla ricetta.")
        case .persistenceFailed:
            return String(localized: "recipes.error.persistenceFailed", defaultValue: "Non è stato possibile salvare. Riprova.")
        }
    }
}

/// Accesso Firestore alla collection `recipes`.
///
/// Contiene solo ciò che il bundle non può contenere: le varianti dell'utente e
/// le ricette canoniche pubblicate dopo l'ultimo aggiornamento dell'app.
final class RecipeRepository {
    /// Firestore si crea alla prima query, non nell'init: così il repository
    /// può essere istanziato anche dove Firebase non è configurato (i test).
    private let firestoreProvider: () -> Firestore

    private var firestore: Firestore { firestoreProvider() }

    init(firestoreProvider: @escaping () -> Firestore = { Firestore.firestore() }) {
        self.firestoreProvider = firestoreProvider
    }

    private var recipesCollection: CollectionReference {
        firestore.collection("recipes")
    }

    /// Ricette canoniche aggiunte lato server dopo la pubblicazione dell'app.
    func fetchCanonicalOverlay() async throws -> [Recipe] {
        let snapshot = try await recipesCollection
            .whereField("visibility", isEqualTo: RecipeVisibility.canonical.rawValue)
            .getDocuments()

        return snapshot.documents.compactMap { Recipe.fromDocument(id: $0.documentID, data: $0.data()) }
    }

    func fetchUserRecipes(for userId: String) async throws -> [Recipe] {
        let snapshot = try await recipesCollection
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { Recipe.fromDocument(id: $0.documentID, data: $0.data()) }
    }

    func observeUserRecipes(
        for userId: String,
        onChange: @escaping (Result<[Recipe], Error>) -> Void
    ) -> ListenerRegistration {
        recipesCollection
            .whereField("ownerId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let recipes = snapshot?.documents.compactMap {
                    Recipe.fromDocument(id: $0.documentID, data: $0.data())
                } ?? []

                onChange(.success(recipes))
            }
    }

    func save(_ recipe: Recipe) async throws {
        guard recipe.visibility.isEditable else { throw RecipeError.canonicalNotEditable }
        guard recipe.ownerId != nil else { throw RecipeError.notAuthenticated }

        try await recipesCollection.document(recipe.id).setData(recipe.documentData, merge: true)
    }

    func delete(recipeId: String) async throws {
        try await recipesCollection.document(recipeId).delete()
    }
}
