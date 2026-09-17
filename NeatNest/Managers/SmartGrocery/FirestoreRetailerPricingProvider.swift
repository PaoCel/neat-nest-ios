import Foundation

struct FirestoreRetailerPricingProvider: RetailerPricingProvider {
    private let repository: SmartGroceryRepository

    init(repository: SmartGroceryRepository = SmartGroceryRepository()) {
        self.repository = repository
    }

    func fetchRetailers() async throws -> [Retailer] {
        try await repository.fetchRetailers()
    }

    func fetchPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice] {
        try await repository.fetchRetailerPrices(for: productCatalogIds)
    }
}
