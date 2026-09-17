import Foundation

struct SeededRetailerPricingProvider: RetailerPricingProvider {
    private let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func fetchRetailers() async throws -> [Retailer] {
        Self.retailers
    }

    func fetchPrices(for productCatalogIds: [String]) async throws -> [RetailerProductPrice] {
        let requestedIds = Set(productCatalogIds)
        guard !requestedIds.isEmpty else {
            return []
        }

        return Self.prices(referenceDate: referenceDate).filter { requestedIds.contains($0.productCatalogId) }
    }
}

private extension SeededRetailerPricingProvider {
    static let retailers: [Retailer] = [
        Retailer(
            id: "esselunga-porta-romana",
            name: "Esselunga",
            cityArea: "Milano Porta Romana",
            isActive: true
        ),
        Retailer(
            id: "lidl-isola",
            name: "Lidl",
            cityArea: "Milano Isola",
            isActive: true
        ),
        Retailer(
            id: "conad-city-navigli",
            name: "Conad City",
            cityArea: "Milano Navigli",
            isActive: true
        )
    ]

    static func prices(referenceDate: Date) -> [RetailerProductPrice] {
        [
            price("esselunga-latte-arborea", retailer: "esselunga-porta-romana", product: "latte-arborea", base: 1.89, promo: 1.69, loyalty: 1.59, updatedHoursAgo: 4, from: referenceDate),
            price("esselunga-latte-senza-lattosio", retailer: "esselunga-porta-romana", product: "latte-senza-lattosio", base: 1.99, promo: nil, loyalty: 1.79, updatedHoursAgo: 5, from: referenceDate),
            price("esselunga-tonno", retailer: "esselunga-porta-romana", product: "tonno-allolio", base: 4.79, promo: 4.19, loyalty: 3.99, updatedHoursAgo: 6, from: referenceDate),
            price("esselunga-zucchine", retailer: "esselunga-porta-romana", product: "zucchine", base: 1.58, promo: nil, loyalty: nil, updatedHoursAgo: 3, from: referenceDate),
            price("esselunga-pasta-barilla", retailer: "esselunga-porta-romana", product: "pasta-barilla", base: 1.49, promo: 1.09, loyalty: 0.99, updatedHoursAgo: 2, from: referenceDate),
            price("esselunga-pane", retailer: "esselunga-porta-romana", product: "pane", base: 2.40, promo: nil, loyalty: nil, updatedHoursAgo: 8, from: referenceDate),
            price("esselunga-uova", retailer: "esselunga-porta-romana", product: "uova", base: 2.59, promo: 2.29, loyalty: nil, updatedHoursAgo: 4, from: referenceDate),
            price("esselunga-yogurt", retailer: "esselunga-porta-romana", product: "yogurt-greco", base: 1.39, promo: nil, loyalty: 1.19, updatedHoursAgo: 7, from: referenceDate),
            price("esselunga-pollo", retailer: "esselunga-porta-romana", product: "petto-di-pollo", base: 5.89, promo: 5.29, loyalty: 4.99, updatedHoursAgo: 6, from: referenceDate),
            price("esselunga-riso", retailer: "esselunga-porta-romana", product: "riso-basmati", base: 3.39, promo: 2.99, loyalty: 2.79, updatedHoursAgo: 3, from: referenceDate),

            unavailable("lidl-latte-arborea", retailer: "lidl-isola", product: "latte-arborea", updatedHoursAgo: 5, from: referenceDate),
            price("lidl-latte-senza-lattosio", retailer: "lidl-isola", product: "latte-senza-lattosio", base: 1.49, promo: nil, loyalty: nil, updatedHoursAgo: 4, from: referenceDate, confidence: 0.93),
            price("lidl-tonno", retailer: "lidl-isola", product: "tonno-allolio", base: 3.69, promo: 3.49, loyalty: nil, updatedHoursAgo: 4, from: referenceDate, confidence: 0.93),
            price("lidl-zucchine", retailer: "lidl-isola", product: "zucchine", base: 1.19, promo: nil, loyalty: nil, updatedHoursAgo: 2, from: referenceDate, confidence: 0.92),
            price("lidl-pasta-barilla", retailer: "lidl-isola", product: "pasta-barilla", base: 1.19, promo: 0.99, loyalty: nil, updatedHoursAgo: 3, from: referenceDate, confidence: 0.92),
            price("lidl-pane", retailer: "lidl-isola", product: "pane", base: 1.69, promo: nil, loyalty: nil, updatedHoursAgo: 8, from: referenceDate, confidence: 0.91),
            price("lidl-uova", retailer: "lidl-isola", product: "uova", base: 1.99, promo: nil, loyalty: nil, updatedHoursAgo: 3, from: referenceDate, confidence: 0.94),
            price("lidl-yogurt", retailer: "lidl-isola", product: "yogurt-greco", base: 0.99, promo: nil, loyalty: nil, updatedHoursAgo: 6, from: referenceDate, confidence: 0.93),
            price("lidl-pollo", retailer: "lidl-isola", product: "petto-di-pollo", base: 4.79, promo: 4.49, loyalty: nil, updatedHoursAgo: 5, from: referenceDate, confidence: 0.92),
            price("lidl-riso", retailer: "lidl-isola", product: "riso-basmati", base: 2.39, promo: 1.99, loyalty: nil, updatedHoursAgo: 2, from: referenceDate, confidence: 0.92),

            price("conad-latte-arborea", retailer: "conad-city-navigli", product: "latte-arborea", base: 1.79, promo: nil, loyalty: nil, updatedHoursAgo: 7, from: referenceDate, confidence: 0.88),
            price("conad-latte-senza-lattosio", retailer: "conad-city-navigli", product: "latte-senza-lattosio", base: 1.89, promo: nil, loyalty: 1.69, updatedHoursAgo: 7, from: referenceDate, confidence: 0.88),
            price("conad-tonno", retailer: "conad-city-navigli", product: "tonno-allolio", base: 4.29, promo: 3.79, loyalty: nil, updatedHoursAgo: 9, from: referenceDate, confidence: 0.87),
            price("conad-zucchine", retailer: "conad-city-navigli", product: "zucchine", base: 1.49, promo: nil, loyalty: nil, updatedHoursAgo: 6, from: referenceDate, confidence: 0.87),
            price("conad-pasta-barilla", retailer: "conad-city-navigli", product: "pasta-barilla", base: 1.59, promo: 1.19, loyalty: 1.09, updatedHoursAgo: 6, from: referenceDate, confidence: 0.89),
            price("conad-pane", retailer: "conad-city-navigli", product: "pane", base: 2.10, promo: nil, loyalty: nil, updatedHoursAgo: 10, from: referenceDate, confidence: 0.86),
            price("conad-uova", retailer: "conad-city-navigli", product: "uova", base: 2.39, promo: nil, loyalty: 2.09, updatedHoursAgo: 6, from: referenceDate, confidence: 0.88),
            price("conad-yogurt", retailer: "conad-city-navigli", product: "yogurt-greco", base: 1.29, promo: nil, loyalty: nil, updatedHoursAgo: 9, from: referenceDate, confidence: 0.87),
            price("conad-pollo", retailer: "conad-city-navigli", product: "petto-di-pollo", base: 5.49, promo: nil, loyalty: nil, updatedHoursAgo: 9, from: referenceDate, confidence: 0.87),
            unavailable("conad-riso", retailer: "conad-city-navigli", product: "riso-basmati", updatedHoursAgo: 8, from: referenceDate)
        ]
    }

    static func price(
        _ id: String,
        retailer: String,
        product: String,
        base: Double,
        promo: Double?,
        loyalty: Double?,
        updatedHoursAgo: Int,
        from referenceDate: Date,
        confidence: Double = 0.95
    ) -> RetailerProductPrice {
        RetailerProductPrice(
            id: id,
            retailerId: retailer,
            productCatalogId: product,
            basePrice: base,
            promoPrice: promo,
            loyaltyPrice: loyalty,
            currency: "EUR",
            isAvailable: true,
            lastUpdatedAt: relativeDate(hoursAgo: updatedHoursAgo, from: referenceDate),
            sourceType: .seeded,
            sourceConfidence: confidence
        )
    }

    static func unavailable(
        _ id: String,
        retailer: String,
        product: String,
        updatedHoursAgo: Int,
        from referenceDate: Date
    ) -> RetailerProductPrice {
        RetailerProductPrice(
            id: id,
            retailerId: retailer,
            productCatalogId: product,
            basePrice: 0,
            promoPrice: nil,
            loyaltyPrice: nil,
            currency: "EUR",
            isAvailable: false,
            lastUpdatedAt: relativeDate(hoursAgo: updatedHoursAgo, from: referenceDate),
            sourceType: .seeded,
            sourceConfidence: 0.82
        )
    }

    static func relativeDate(hoursAgo: Int, from referenceDate: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: referenceDate) ?? referenceDate
    }
}
