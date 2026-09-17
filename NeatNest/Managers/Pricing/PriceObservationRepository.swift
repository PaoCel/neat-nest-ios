import Foundation
import FirebaseFirestore

/// Accesso alla collection `priceObservations`.
///
/// Append-only per scelta: un'osservazione è un fatto storico, non uno stato da
/// aggiornare. Nessun documento contiene l'identità di chi ha contribuito.
final class PriceObservationRepository {
    private let firestoreProvider: () -> Firestore

    private var firestore: Firestore { firestoreProvider() }

    init(firestoreProvider: @escaping () -> Firestore = { Firestore.firestore() }) {
        self.firestoreProvider = firestoreProvider
    }

    private var collection: CollectionReference {
        firestore.collection("priceObservations")
    }

    func record(_ observations: [PriceObservation]) async throws {
        let usable = observations.filter(\.isUsable)
        guard !usable.isEmpty else { return }

        for chunk in usable.chunked(into: 400) {
            let batch = firestore.batch()
            for observation in chunk {
                batch.setData(observation.documentData, forDocument: collection.document(observation.id))
            }
            try await batch.commit()
        }
    }

    /// Osservazioni recenti per un insieme di prodotti.
    ///
    /// Firestore limita `in` a 30 valori per query, quindi si spezza.
    func fetchRecent(
        productCatalogIds: [String],
        since: Date,
        limitPerChunk: Int = 300
    ) async throws -> [PriceObservation] {
        guard !productCatalogIds.isEmpty else { return [] }

        var results: [PriceObservation] = []

        for chunk in productCatalogIds.chunked(into: 30) {
            let snapshot = try await collection
                .whereField("productCatalogId", in: chunk)
                .whereField("observedAt", isGreaterThan: Timestamp(date: since))
                .order(by: "observedAt", descending: true)
                .limit(to: limitPerChunk)
                .getDocuments()

            results.append(contentsOf: snapshot.documents.compactMap {
                PriceObservation.fromDocument(id: $0.documentID, data: $0.data())
            })
        }

        return results
    }
}

/// Fornisce i prezzi a `Let's Shop` partendo dagli scontrini della community
/// invece che da un dataset fisso.
final class ObservedRetailerPricingProvider: RetailerPricingProvider {
    private let observationRepository: PriceObservationRepository
    private let groceryRepository: SmartGroceryRepository
    private let aggregator: PriceObservationAggregator
    private let windowDays: Double

    init(
        observationRepository: PriceObservationRepository = PriceObservationRepository(),
        groceryRepository: SmartGroceryRepository = SmartGroceryRepository(),
        aggregator: PriceObservationAggregator = PriceObservationAggregator(),
        windowDays: Double = 90
    ) {
        self.observationRepository = observationRepository
        self.groceryRepository = groceryRepository
        self.aggregator = aggregator
        self.windowDays = windowDays
    }

    func fetchRetailers() async throws -> [Retailer] {
        try await groceryRepository.fetchRetailers()
    }

    func fetchPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice] {
        let since = Date().addingTimeInterval(-windowDays * 86_400)
        let observations = try await observationRepository.fetchRecent(
            productCatalogIds: productCatalogIds,
            since: since
        )

        return aggregator.aggregate(observations)
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
