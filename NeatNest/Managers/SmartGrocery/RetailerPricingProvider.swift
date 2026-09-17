import Foundation

protocol RetailerPricingProvider {
    func fetchRetailers() async throws -> [Retailer]
    func fetchPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice]
}
