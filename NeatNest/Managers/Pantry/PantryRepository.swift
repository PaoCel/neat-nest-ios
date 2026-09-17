import Foundation
import FirebaseFirestore

enum PantryError: Error, LocalizedError {
    case notAuthenticated
    case emptyName
    case invalidQuantity
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "pantry.error.notAuthenticated", defaultValue: "Accedi per gestire la dispensa.")
        case .emptyName:
            return String(localized: "pantry.error.emptyName", defaultValue: "Dai un nome al prodotto prima di salvarlo.")
        case .invalidQuantity:
            return String(localized: "pantry.error.invalidQuantity", defaultValue: "Inserisci una quantità maggiore di zero.")
        case .persistenceFailed:
            return String(localized: "pantry.error.persistenceFailed", defaultValue: "Non è stato possibile salvare. Riprova.")
        }
    }
}

/// Accesso Firestore alla collection `pantryItems`.
final class PantryRepository {
    /// Firestore si crea alla prima query, non nell'init: così il repository
    /// può essere istanziato anche dove Firebase non è configurato (i test).
    private let firestoreProvider: () -> Firestore

    private var firestore: Firestore { firestoreProvider() }

    init(firestoreProvider: @escaping () -> Firestore = { Firestore.firestore() }) {
        self.firestoreProvider = firestoreProvider
    }

    private var itemsCollection: CollectionReference {
        firestore.collection("pantryItems")
    }

    func observeItems(
        for userId: String,
        onChange: @escaping (Result<[PantryItem], Error>) -> Void
    ) -> ListenerRegistration {
        itemsCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap { document in
                    PantryItem.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(items))
            }
    }

    func fetchItems(for userId: String) async throws -> [PantryItem] {
        let snapshot = try await itemsCollection
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            PantryItem.fromDocument(id: document.documentID, data: document.data())
        }
    }

    func save(_ item: PantryItem) async throws {
        try await itemsCollection
            .document(item.id)
            .setData(item.documentData, merge: true)
    }

    func save(_ items: [PantryItem]) async throws {
        guard !items.isEmpty else { return }

        for chunk in items.chunked(into: 400) {
            let batch = firestore.batch()
            for item in chunk {
                batch.setData(item.documentData, forDocument: itemsCollection.document(item.id), merge: true)
            }
            try await batch.commit()
        }
    }

    func delete(itemId: String) async throws {
        try await itemsCollection.document(itemId).delete()
    }

    func delete(itemIds: [String]) async throws {
        guard !itemIds.isEmpty else { return }

        for chunk in itemIds.chunked(into: 400) {
            let batch = firestore.batch()
            for id in chunk {
                batch.deleteDocument(itemsCollection.document(id))
            }
            try await batch.commit()
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }

        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
