import Foundation
import FirebaseFirestore

final class SmartGroceryRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    private var listsCollection: CollectionReference {
        firestore.collection("groceryLists")
    }

    private var itemsCollection: CollectionReference {
        firestore.collection("groceryListItems")
    }

    private var catalogCollection: CollectionReference {
        firestore.collection("productCatalog")
    }

    private var retailersCollection: CollectionReference {
        firestore.collection("retailers")
    }

    private var retailerPricesCollection: CollectionReference {
        firestore.collection("retailerProductPrices")
    }

    func observeLists(
        for userId: String,
        onChange: @escaping (Result<[UserGroceryList], Error>) -> Void
    ) -> ListenerRegistration {
        listsCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    onChange(.failure(error))
                    return
                }

                let lists = snapshot?.documents.compactMap { document in
                    UserGroceryList.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(self.sortedLists(lists)))
            }
    }

    func observeAllItems(
        for userId: String,
        onChange: @escaping (Result<[UserGroceryListItem], Error>) -> Void
    ) -> ListenerRegistration {
        itemsCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap { document in
                    UserGroceryListItem.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(self.sortedItems(items)))
            }
    }

    func observeItems(
        for listId: String,
        userId: String,
        onChange: @escaping (Result<[UserGroceryListItem], Error>) -> Void
    ) -> ListenerRegistration {
        itemsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("listId", isEqualTo: listId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap { document in
                    UserGroceryListItem.fromDocument(id: document.documentID, data: document.data())
                } ?? []

                onChange(.success(self.sortedItems(items)))
            }
    }

    func fetchLists(for userId: String) async throws -> [UserGroceryList] {
        let snapshot = try await getDocuments(from: listsCollection.whereField("userId", isEqualTo: userId))
        let lists = snapshot.documents.compactMap { document in
            UserGroceryList.fromDocument(id: document.documentID, data: document.data())
        }
        return sortedLists(lists)
    }

    func fetchCatalog() async throws -> [ProductCatalogItem] {
        let snapshot = try await getDocuments(from: catalogCollection.whereField("isActive", isEqualTo: true))
        let items = snapshot.documents.compactMap { document in
            ProductCatalogItem.fromDocument(id: document.documentID, data: document.data())
        }

        return items.sorted {
            $0.canonicalName.localizedCaseInsensitiveCompare($1.canonicalName) == .orderedAscending
        }
    }

    func fetchRetailers() async throws -> [Retailer] {
        let snapshot = try await getDocuments(from: retailersCollection.whereField("isActive", isEqualTo: true))
        let retailers = snapshot.documents.compactMap { document in
            Retailer.fromDocument(id: document.documentID, data: document.data())
        }

        return retailers.sorted { lhs, rhs in
            if lhs.name != rhs.name {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return (lhs.cityArea ?? "").localizedCaseInsensitiveCompare(rhs.cityArea ?? "") == .orderedAscending
        }
    }

    func fetchRetailerPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice] {
        let requestedIds = Array(Set(productCatalogIds.filter { !$0.isEmpty })).sorted()
        guard !requestedIds.isEmpty else {
            return []
        }

        var prices: [RetailerProductPrice] = []
        for chunk in requestedIds.chunked(into: 10) {
            let snapshot = try await getDocuments(
                from: retailerPricesCollection.whereField("productCatalogId", in: chunk)
            )

            prices.append(contentsOf: snapshot.documents.compactMap { document in
                RetailerProductPrice.fromDocument(id: document.documentID, data: document.data())
            })
        }

        var seenIds = Set<String>()
        return prices
            .filter { seenIds.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.productCatalogId != rhs.productCatalogId {
                    return lhs.productCatalogId.localizedCaseInsensitiveCompare(rhs.productCatalogId) == .orderedAscending
                }

                return lhs.retailerId.localizedCaseInsensitiveCompare(rhs.retailerId) == .orderedAscending
            }
    }

    func fetchAllItems(for userId: String) async throws -> [UserGroceryListItem] {
        let snapshot = try await getDocuments(
            from: itemsCollection.whereField("userId", isEqualTo: userId)
        )

        let items = snapshot.documents.compactMap { document in
            UserGroceryListItem.fromDocument(id: document.documentID, data: document.data())
        }

        return sortedItems(items)
    }

    func fetchItems(for listId: String, userId: String) async throws -> [UserGroceryListItem] {
        let snapshot = try await getDocuments(
            from: itemsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("listId", isEqualTo: listId)
        )

        let items = snapshot.documents.compactMap { document in
            UserGroceryListItem.fromDocument(id: document.documentID, data: document.data())
        }

        return sortedItems(items)
    }

    func seedCatalogIfNeeded(with items: [ProductCatalogItem]) async throws {
        let snapshot = try await getDocuments(from: catalogCollection.limit(to: 1))
        guard snapshot.documents.isEmpty else {
            return
        }

        let batch = firestore.batch()
        for item in items {
            batch.setData(catalogPayload(from: item), forDocument: catalogCollection.document(item.id), merge: true)
        }
        try await commit(batch)
    }

    func createList(userId: String, title: String, isDefault: Bool) async throws -> UserGroceryList {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = listsCollection.document()

        try await setData(
            on: document,
            data: [
                "userId": userId,
                "title": trimmedTitle,
                "isDefault": isDefault,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: false
        )

        return UserGroceryList(
            id: document.documentID,
            userId: userId,
            title: trimmedTitle,
            createdAt: Date(),
            updatedAt: Date(),
            isDefault: isDefault
        )
    }

    func updateListTitle(listId: String, title: String) async throws {
        try await updateData(
            on: listsCollection.document(listId),
            data: [
                "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": FieldValue.serverTimestamp()
            ]
        )
    }

    func setListDefault(listId: String, isDefault: Bool) async throws {
        try await updateData(
            on: listsCollection.document(listId),
            data: [
                "isDefault": isDefault,
                "updatedAt": FieldValue.serverTimestamp()
            ]
        )
    }

    func createItem(_ item: UserGroceryListItem) async throws {
        try await setData(
            on: itemsCollection.document(item.id),
            data: itemCreatePayload(from: item),
            merge: false
        )
    }

    func updateItem(_ item: UserGroceryListItem) async throws {
        try await setData(
            on: itemsCollection.document(item.id),
            data: itemUpdatePayload(from: item),
            merge: true
        )
    }

    func deleteList(listId: String, userId: String) async throws {
        let itemsSnapshot = try await getDocuments(
            from: itemsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("listId", isEqualTo: listId)
        )

        let batch = firestore.batch()
        batch.deleteDocument(listsCollection.document(listId))
        itemsSnapshot.documents.forEach { document in
            batch.deleteDocument(document.reference)
        }
        try await commit(batch)
    }
}

private extension SmartGroceryRepository {
    func sortedLists(_ lists: [UserGroceryList]) -> [UserGroceryList] {
        lists.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault && !rhs.isDefault
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func sortedItems(_ items: [UserGroceryListItem]) -> [UserGroceryListItem] {
        items.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func catalogPayload(from item: ProductCatalogItem) -> [String: Any] {
        var data: [String: Any] = [
            "canonicalName": item.canonicalName,
            "category": item.category,
            "aliases": item.aliases,
            "searchableTokens": item.searchableTokens,
            "isActive": item.isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let brand = item.brand, !brand.isEmpty {
            data["brand"] = brand
        }

        if let subcategory = item.subcategory, !subcategory.isEmpty {
            data["subcategory"] = subcategory
        }

        if let sizeLabel = item.sizeLabel, !sizeLabel.isEmpty {
            data["sizeLabel"] = sizeLabel
        }

        if let barcode = item.barcode, !barcode.isEmpty {
            data["barcode"] = barcode
        }

        return data
    }

    func itemCreatePayload(from item: UserGroceryListItem) -> [String: Any] {
        var data = itemBasePayload(from: item)
        data["createdAt"] = FieldValue.serverTimestamp()
        data["updatedAt"] = FieldValue.serverTimestamp()
        return data
    }

    func itemUpdatePayload(from item: UserGroceryListItem) -> [String: Any] {
        var data = itemBasePayload(from: item)
        data["updatedAt"] = FieldValue.serverTimestamp()
        return data
    }

    func itemBasePayload(from item: UserGroceryListItem) -> [String: Any] {
        var data: [String: Any] = [
            "listId": item.listId,
            "userId": item.userId,
            "rawInputText": item.rawInputText,
            "quantity": item.quantity,
            "status": item.status.rawValue
        ]

        if let normalizedName = item.normalizedName, !normalizedName.isEmpty {
            data["normalizedName"] = normalizedName
        }

        if let productCatalogId = item.productCatalogId, !productCatalogId.isEmpty {
            data["productCatalogId"] = productCatalogId
        }

        if let unit = item.unit, !unit.isEmpty {
            data["unit"] = unit
        }

        if let lastPurchasedAt = item.lastPurchasedAt {
            data["lastPurchasedAt"] = Timestamp(date: lastPurchasedAt)
        }

        if let notes = item.notes, !notes.isEmpty {
            data["notes"] = notes
        }

        if let catalogEnrichmentStatus = item.catalogEnrichmentStatus {
            data["catalogEnrichmentStatus"] = catalogEnrichmentStatus.rawValue
        }

        if let catalogEnrichmentSource = item.catalogEnrichmentSource, !catalogEnrichmentSource.isEmpty {
            data["catalogEnrichmentSource"] = catalogEnrichmentSource
        }

        if let catalogEnrichmentConfidence = item.catalogEnrichmentConfidence {
            data["catalogEnrichmentConfidence"] = catalogEnrichmentConfidence
        }

        if let catalogEnrichmentUpdatedAt = item.catalogEnrichmentUpdatedAt {
            data["catalogEnrichmentUpdatedAt"] = Timestamp(date: catalogEnrichmentUpdatedAt)
        }

        return data
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

    func setData(on document: DocumentReference, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateData(on document: DocumentReference, data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.updateData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
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
        NSError(domain: "SmartGroceryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else {
            return isEmpty ? [] : [self]
        }

        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
