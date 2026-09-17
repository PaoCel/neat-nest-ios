import Foundation

@MainActor
final class LetsShopService {
    private let repository: SmartGroceryRepository
    private let groceryService: SmartGroceryService
    private let pricingProvider: any RetailerPricingProvider
    private let engine: ShoppingRecommendationEngine

    init(
        repository: SmartGroceryRepository = SmartGroceryRepository(),
        groceryService: SmartGroceryService? = nil,
        pricingProvider: (any RetailerPricingProvider)? = nil,
        engine: ShoppingRecommendationEngine = ShoppingRecommendationEngine()
    ) {
        self.repository = repository
        self.groceryService = groceryService ?? SmartGroceryService(repository: repository)
        self.pricingProvider = pricingProvider ?? CompositeRetailerPricingProvider(
            primary: FirestoreRetailerPricingProvider(repository: repository),
            fallback: SeededRetailerPricingProvider()
        )
        self.engine = engine
    }

    func loadPreparation(for list: UserGroceryList, userId: String) async throws -> LetsShopPreparationSummary {
        let activeItems = try await repository.fetchItems(for: list.id, userId: userId)
            .filter { $0.status == .active }

        let catalog = await groceryService.prepareCatalog()
        let catalogIds = Set(catalog.map(\.id))
        let productIds = Array(Set(activeItems.compactMap(\.productCatalogId)))
        let retailers = try await pricingProvider.fetchRetailers()
        let prices = try await pricingProvider.fetchPrices(for: productIds)

        let resolvedCount = activeItems.filter {
            guard let productCatalogId = $0.productCatalogId else {
                return false
            }

            return catalogIds.contains(productCatalogId)
        }.count

        let pricedProductIds = Set(
            prices
                .filter(\.isAvailable)
                .map(\.productCatalogId)
        )

        let pricedCount = activeItems.filter {
            guard let productCatalogId = $0.productCatalogId else {
                return false
            }

            return pricedProductIds.contains(productCatalogId)
        }.count

        return LetsShopPreparationSummary(
            list: list,
            activeItems: activeItems,
            resolvedCount: resolvedCount,
            unresolvedCount: max(0, activeItems.count - resolvedCount),
            pricedCount: pricedCount,
            retailers: retailers.filter(\.isActive),
            latestPriceUpdate: prices.map(\.lastUpdatedAt).max()
        )
    }

    func generateRecommendations(
        for list: UserGroceryList,
        userId: String,
        preferenceValue: Double,
        considerLoyaltyPricing: Bool
    ) async throws -> ShoppingRecommendationSet {
        let activeItems = try await repository.fetchItems(for: list.id, userId: userId)
            .filter { $0.status == .active }

        let catalog = await groceryService.prepareCatalog()
        let productIds = Array(Set(activeItems.compactMap(\.productCatalogId)))
        let retailers = try await pricingProvider.fetchRetailers()
        let prices = try await pricingProvider.fetchPrices(for: productIds)

        return engine.buildRecommendations(
            for: list,
            activeItems: activeItems,
            catalog: catalog,
            retailers: retailers,
            prices: prices,
            preferenceValue: preferenceValue,
            considerLoyaltyPricing: considerLoyaltyPricing
        )
    }
}
