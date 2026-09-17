import Foundation
import FirebaseFirestore

enum MoneyError: Error, LocalizedError {
    case invalidAmount
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return String(localized: "money.error.invalidAmount", defaultValue: "Inserisci un importo maggiore di zero.")
        case .persistenceFailed:
            return String(localized: "money.error.persistenceFailed", defaultValue: "Non è stato possibile salvare. Riprova.")
        }
    }
}

/// Accesso Firestore alla collection `moneyEntries`.
final class MoneyRepository {
    private let firestoreProvider: () -> Firestore

    private var firestore: Firestore { firestoreProvider() }

    init(firestoreProvider: @escaping () -> Firestore = { Firestore.firestore() }) {
        self.firestoreProvider = firestoreProvider
    }

    private var collection: CollectionReference {
        firestore.collection("moneyEntries")
    }

    func observeEntries(
        for userId: String,
        onChange: @escaping (Result<[MoneyEntry], Error>) -> Void
    ) -> ListenerRegistration {
        collection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let entries = snapshot?.documents.compactMap {
                    MoneyEntry.fromDocument(id: $0.documentID, data: $0.data())
                } ?? []

                onChange(.success(entries.sorted { $0.date > $1.date }))
            }
    }

    func save(_ entry: MoneyEntry) async throws {
        guard entry.amount > 0 else { throw MoneyError.invalidAmount }
        try await collection.document(entry.id).setData(entry.documentData, merge: true)
    }

    func delete(entryId: String) async throws {
        try await collection.document(entryId).delete()
    }
}
