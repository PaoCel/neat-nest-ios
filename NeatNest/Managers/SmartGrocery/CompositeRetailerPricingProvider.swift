import Foundation

struct CompositeRetailerPricingProvider: RetailerPricingProvider {
    private let primary: any RetailerPricingProvider
    private let fallback: any RetailerPricingProvider

    init(
        primary: any RetailerPricingProvider,
        fallback: any RetailerPricingProvider
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetchRetailers() async throws -> [Retailer] {
        let primaryRetailers = try? await primary.fetchRetailers()
        let fallbackRetailers = try? await fallback.fetchRetailers()

        if let primaryRetailers, !primaryRetailers.isEmpty {
            return mergedRetailers(primary: primaryRetailers, fallback: fallbackRetailers ?? [])
        }

        if let fallbackRetailers, !fallbackRetailers.isEmpty {
            return fallbackRetailers
        }

        throw Self.providerError("Non riesco a caricare i retailer Smart Grocery.")
    }

    func fetchPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice] {
        let requestedIds = Array(Set(productCatalogIds.filter { !$0.isEmpty })).sorted()
        guard !requestedIds.isEmpty else {
            return []
        }

        if let primaryPrices = try? await primary.fetchPrices(for: requestedIds),
           !primaryPrices.isEmpty {
            let coveredProductIds = Set(primaryPrices.map(\.productCatalogId))
            let missingProductIds = requestedIds.filter { !coveredProductIds.contains($0) }
            let fallbackPrices = missingProductIds.isEmpty ? [] : ((try? await fallback.fetchPrices(for: missingProductIds)) ?? [])
            return mergedPrices(primary: primaryPrices, fallback: fallbackPrices)
        }

        let fallbackPrices = try await fallback.fetchPrices(for: requestedIds)
        if !fallbackPrices.isEmpty {
            return fallbackPrices
        }

        throw Self.providerError("Non riesco a caricare i prezzi Smart Grocery.")
    }
}

private extension CompositeRetailerPricingProvider {
    func mergedRetailers(primary: [Retailer], fallback: [Retailer]) -> [Retailer] {
        var retailersById = Dictionary(uniqueKeysWithValues: primary.map { ($0.id, $0) })

        for retailer in fallback where retailersById[retailer.id] == nil {
            retailersById[retailer.id] = retailer
        }

        return retailersById.values.sorted { lhs, rhs in
            if lhs.name != rhs.name {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return (lhs.cityArea ?? "").localizedCaseInsensitiveCompare(rhs.cityArea ?? "") == .orderedAscending
        }
    }

    func mergedPrices(primary: [RetailerProductPrice], fallback: [RetailerProductPrice]) -> [RetailerProductPrice] {
        var pricesByKey = [String: RetailerProductPrice]()

        for price in primary {
            pricesByKey[priceKey(for: price)] = price
        }

        for price in fallback where pricesByKey[priceKey(for: price)] == nil {
            pricesByKey[priceKey(for: price)] = price
        }

        return pricesByKey.values.sorted { lhs, rhs in
            if lhs.productCatalogId != rhs.productCatalogId {
                return lhs.productCatalogId.localizedCaseInsensitiveCompare(rhs.productCatalogId) == .orderedAscending
            }

            return lhs.retailerId.localizedCaseInsensitiveCompare(rhs.retailerId) == .orderedAscending
        }
    }

    func priceKey(for price: RetailerProductPrice) -> String {
        "\(price.retailerId)::\(price.productCatalogId)"
    }

    static func providerError(_ message: String) -> NSError {
        NSError(domain: "CompositeRetailerPricingProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
