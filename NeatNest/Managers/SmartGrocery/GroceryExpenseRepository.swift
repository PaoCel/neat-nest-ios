import Foundation
import FirebaseFirestore

final class GroceryExpenseRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    private var receiptImportsCollection: CollectionReference {
        firestore.collection("groceryReceiptImports")
    }

    private var receiptLineItemsCollection: CollectionReference {
        firestore.collection("groceryReceiptLineItems")
    }

    func observeReceiptImports(
        for userId: String,
        onChange: @escaping (Result<[ReceiptImport], Error>) -> Void
    ) -> ListenerRegistration {
        receiptImportsCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    onChange(.failure(error))
                    return
                }

                let imports = snapshot?.documents.compactMap { document in
                    ReceiptImport.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(self.sortedReceipts(imports)))
            }
    }

    func observeReceiptLineItems(
        for userId: String,
        onChange: @escaping (Result<[ReceiptLineItem], Error>) -> Void
    ) -> ListenerRegistration {
        receiptLineItemsCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap { document in
                    ReceiptLineItem.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(self.sortedLineItems(items)))
            }
    }

    func fetchReceiptImports(for userId: String) async throws -> [ReceiptImport] {
        let snapshot = try await getDocuments(
            from: receiptImportsCollection.whereField("userId", isEqualTo: userId)
        )

        let imports = snapshot.documents.compactMap { document in
            ReceiptImport.fromDocument(id: document.documentID, data: document.data())
        }

        return sortedReceipts(imports)
    }

    func fetchReceiptLineItems(for userId: String) async throws -> [ReceiptLineItem] {
        let snapshot = try await getDocuments(
            from: receiptLineItemsCollection.whereField("userId", isEqualTo: userId)
        )

        let items = snapshot.documents.compactMap { document in
            ReceiptLineItem.fromDocument(id: document.documentID, data: document.data())
        }

        return sortedLineItems(items)
    }

    func createReceiptImport(_ receiptImport: ReceiptImport, lineItems: [ReceiptLineItem]) async throws {
        let batch = firestore.batch()

        batch.setData(
            receiptImportPayload(from: receiptImport),
            forDocument: receiptImportsCollection.document(receiptImport.id),
            merge: false
        )

        for lineItem in lineItems {
            batch.setData(
                receiptLineItemPayload(from: lineItem),
                forDocument: receiptLineItemsCollection.document(lineItem.id),
                merge: false
            )
        }

        try await commit(batch)
    }
}

private extension GroceryExpenseRepository {
    func sortedReceipts(_ imports: [ReceiptImport]) -> [ReceiptImport] {
        imports.sorted { lhs, rhs in
            if lhs.purchaseDate != rhs.purchaseDate {
                return lhs.purchaseDate > rhs.purchaseDate
            }

            return lhs.createdAt > rhs.createdAt
        }
    }

    func sortedLineItems(_ items: [ReceiptLineItem]) -> [ReceiptLineItem] {
        items.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func receiptImportPayload(from receiptImport: ReceiptImport) -> [String: Any] {
        [
            "userId": receiptImport.userId,
            "retailerName": receiptImport.retailerName,
            "purchaseDate": Timestamp(date: receiptImport.purchaseDate),
            "totalAmount": receiptImport.totalAmount,
            "currency": receiptImport.currency,
            "sourceType": receiptImport.sourceType.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }

    func receiptLineItemPayload(from lineItem: ReceiptLineItem) -> [String: Any] {
        var payload: [String: Any] = [
            "receiptImportId": lineItem.receiptImportId,
            "userId": lineItem.userId,
            "rawLineText": lineItem.rawLineText,
            "normalizedName": lineItem.normalizedName,
            "lineTotal": lineItem.lineTotal,
            "inferredCategory": lineItem.inferredCategory.rawValue,
            "confidence": lineItem.confidence,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let productCatalogId = lineItem.productCatalogId, !productCatalogId.isEmpty {
            payload["productCatalogId"] = productCatalogId
        }

        if let quantity = lineItem.quantity {
            payload["quantity"] = quantity
        }

        if let unitPrice = lineItem.unitPrice {
            payload["unitPrice"] = unitPrice
        }

        return payload
    }

    func getDocuments(from query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: Self.repositoryError("Missing Firestore snapshot"))
                }
            }
        }
    }

    func commit(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func repositoryError(_ message: String) -> NSError {
        NSError(domain: "GroceryExpenseRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
