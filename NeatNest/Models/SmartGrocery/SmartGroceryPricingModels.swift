import Foundation

enum RetailerPriceSourceType: String, CaseIterable, Hashable {
    case seeded
    case demo
    case adminImport
    case provider
    case flyer
    /// Prezzo visto su uno scontrino reale: la fonte più fresca e più locale
    /// che l'app possa avere.
    case receipt

    var title: LocalizedStringResource {
        switch self {
        case .seeded:
            return "Seeded"
        case .demo:
            return "Demo"
        case .adminImport:
            return "Admin Import"
        case .provider:
            return "Provider"
        case .flyer:
            return "Flyer"
        case .receipt:
            return "Da scontrino"
        }
    }

    /// Quanto pesa questa fonte prima che l'età la sbiadisca.
    ///
    /// Uno scontrino è un fatto: qualcuno ha pagato quella cifra a quella cassa.
    /// Un volantino è una promessa, un dato seeded è un segnaposto.
    var baseConfidence: Double {
        switch self {
        case .receipt:
            return 1
        case .provider:
            return 0.85
        case .flyer:
            return 0.7
        case .adminImport:
            return 0.6
        case .demo, .seeded:
            return 0.3
        }
    }

    /// Titolo già risolto, per i componenti che accettano solo `String`.
    var localizedTitle: String {
        String(localized: title)
    }

    static func from(rawValue: String?) -> RetailerPriceSourceType {
        guard let rawValue,
              let sourceType = RetailerPriceSourceType(rawValue: rawValue) else {
            return .provider
        }

        return sourceType
    }
}

struct Retailer: Identifiable, Hashable {
    let id: String
    let name: String
    let cityArea: String?
    let isActive: Bool
    let chainId: String?
    let chainName: String?
    let storeCode: String?
    let address: String?
    let province: String?
    let zipCode: String?
    let latitude: Double?
    let longitude: Double?

    init(
        id: String,
        name: String,
        cityArea: String?,
        isActive: Bool,
        chainId: String? = nil,
        chainName: String? = nil,
        storeCode: String? = nil,
        address: String? = nil,
        province: String? = nil,
        zipCode: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.cityArea = cityArea
        self.isActive = isActive
        self.chainId = chainId
        self.chainName = chainName
        self.storeCode = storeCode
        self.address = address
        self.province = province
        self.zipCode = zipCode
        self.latitude = latitude
        self.longitude = longitude
    }

    var displayName: String {
        if let cityArea {
            return "\(name) — \(cityArea)"
        }
        return name
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    static func fromDocument(id: String, data: [String: Any]) -> Retailer? {
        guard let name = data["name"] as? String else {
            return nil
        }

        return Retailer(
            id: id,
            name: name,
            cityArea: data["cityArea"] as? String,
            isActive: data["isActive"] as? Bool ?? true,
            chainId: data["chainId"] as? String,
            chainName: data["chainName"] as? String,
            storeCode: data["storeCode"] as? String,
            address: data["address"] as? String,
            province: data["province"] as? String,
            zipCode: data["zipCode"] as? String,
            latitude: data["latitude"].flatMap { value in
                let parsedValue = groceryDoubleValue(from: value)
                return parsedValue != 0 ? parsedValue : nil
            },
            longitude: data["longitude"].flatMap { value in
                let parsedValue = groceryDoubleValue(from: value)
                return parsedValue != 0 ? parsedValue : nil
            }
        )
    }
}

struct RetailerProductPrice: Identifiable, Hashable {
    let id: String
    let retailerId: String
    let productCatalogId: String
    let basePrice: Double
    let promoPrice: Double?
    let loyaltyPrice: Double?
    let currency: String
    let isAvailable: Bool
    let lastUpdatedAt: Date
    let sourceType: RetailerPriceSourceType
    let sourceConfidence: Double

    static func fromDocument(id: String, data: [String: Any]) -> RetailerProductPrice? {
        guard let retailerId = data["retailerId"] as? String,
              let productCatalogId = data["productCatalogId"] as? String else {
            return nil
        }

        return RetailerProductPrice(
            id: id,
            retailerId: retailerId,
            productCatalogId: productCatalogId,
            basePrice: groceryDoubleValue(from: data["basePrice"]),
            promoPrice: data["promoPrice"].flatMap { value in
                let parsedValue = groceryDoubleValue(from: value)
                return parsedValue > 0 ? parsedValue : nil
            },
            loyaltyPrice: data["loyaltyPrice"].flatMap { value in
                let parsedValue = groceryDoubleValue(from: value)
                return parsedValue > 0 ? parsedValue : nil
            },
            currency: data["currency"] as? String ?? "EUR",
            isAvailable: data["isAvailable"] as? Bool ?? true,
            lastUpdatedAt: groceryDateValue(from: data["lastUpdatedAt"]) ??
                groceryDateValue(from: data["updatedAt"]) ??
                Date(),
            sourceType: RetailerPriceSourceType.from(rawValue: data["sourceType"] as? String),
            sourceConfidence: max(0, min(1, groceryDoubleValue(from: data["sourceConfidence"], defaultValue: 0.8)))
        )
    }

    func effectivePrice(considerLoyaltyPricing: Bool) -> Double {
        var candidates = [basePrice]

        if let promoPrice {
            candidates.append(promoPrice)
        }

        if considerLoyaltyPricing, let loyaltyPrice {
            candidates.append(loyaltyPrice)
        }

        return candidates.min() ?? basePrice
    }

    func pricingBadge(considerLoyaltyPricing: Bool) -> String? {
        if considerLoyaltyPricing,
           let loyaltyPrice,
           abs(loyaltyPrice - effectivePrice(considerLoyaltyPricing: true)) < 0.0001 {
            return "Loyalty"
        }

        if let promoPrice,
           abs(promoPrice - effectivePrice(considerLoyaltyPricing: considerLoyaltyPricing)) < 0.0001 {
            return "Promo"
        }

        return nil
    }
}

enum ShoppingRecommendationKind: String, CaseIterable, Identifiable {
    case convenience
    case balanced
    case savings

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .convenience:
            return "Convenienza"
        case .balanced:
            return "Bilanciato"
        case .savings:
            return "Risparmio"
        }
    }

    /// Titolo già risolto, per i componenti che accettano solo `String`.
    var localizedTitle: String {
        String(localized: title)
    }

    var subtitle: String {
        switch self {
        case .convenience:
            return "Preferisce un solo punto vendita e riduce il giro."
        case .balanced:
            return "Cerca il miglior compromesso tra prezzo e praticita."
        case .savings:
            return "Spinge sul totale piu basso, anche distribuendo la spesa."
        }
    }

    var premiumDescription: String {
        switch self {
        case .convenience:
            return "Un piano lineare: un solo supermercato, poca fatica mentale e piu velocita in cassa."
        case .balanced:
            return "Un percorso intelligente: risparmia dove conta senza trasformare la spesa in una caccia al volantino."
        case .savings:
            return "Massimizza il risparmio sul carrello e sfrutta ogni opportunita rilevante di promo o loyalty."
        }
    }

    var sliderRangeLabel: String {
        switch self {
        case .convenience:
            return "0-30"
        case .balanced:
            return "31-70"
        case .savings:
            return "71-100"
        }
    }

    static func fromSliderValue(_ value: Double) -> ShoppingRecommendationKind {
        switch value {
        case ...30:
            return .convenience
        case 31...70:
            return .balanced
        default:
            return .savings
        }
    }
}

struct LetsShopPreparationSummary {
    let list: UserGroceryList
    let activeItems: [UserGroceryListItem]
    let resolvedCount: Int
    let unresolvedCount: Int
    let pricedCount: Int
    let retailers: [Retailer]
    let latestPriceUpdate: Date?

    var activeCount: Int {
        activeItems.count
    }

    var previewItems: [UserGroceryListItem] {
        Array(activeItems.prefix(4))
    }
}

struct ShoppingBasketAssignment: Identifiable, Hashable {
    let item: UserGroceryListItem
    let catalogItem: ProductCatalogItem
    let retailer: Retailer
    let retailerPrice: RetailerProductPrice
    let unitPrice: Double
    let estimatedTotal: Double
    let pricingBadge: String?

    var id: String { item.id }
}

struct ShoppingStoreBreakdown: Identifiable, Hashable {
    let retailer: Retailer
    let assignments: [ShoppingBasketAssignment]
    let subtotal: Double
    let averageConfidence: Double
    let latestPriceUpdate: Date?

    var id: String { retailer.id }
}

struct ShoppingRecommendationMissingItem: Identifiable, Hashable {
    let item: UserGroceryListItem
    let matchedProductName: String?
    let displayReason: String

    var id: String { item.id }
}

struct ShoppingRecommendation: Identifiable, Hashable {
    let kind: ShoppingRecommendationKind
    let title: String
    let summary: String
    let storeBreakdowns: [ShoppingStoreBreakdown]
    let estimatedTotal: Double
    let totalConsideredItems: Int
    let missingPricedItems: [ShoppingRecommendationMissingItem]
    let unresolvedItems: [ShoppingRecommendationMissingItem]
    let overallConfidence: Double
    let freshestUpdate: Date?
    let stalestUpdate: Date?

    var id: String { kind.rawValue }

    var primaryRetailer: Retailer? {
        storeBreakdowns.first?.retailer
    }

    var storeCount: Int {
        storeBreakdowns.count
    }

    var coveredItemCount: Int {
        storeBreakdowns.reduce(0) { $0 + $1.assignments.count }
    }

    var missingCount: Int {
        missingPricedItems.count + unresolvedItems.count
    }
}

struct ShoppingRecommendationSet: Identifiable, Hashable {
    let id: String
    let list: UserGroceryList
    let generatedAt: Date
    let preferenceValue: Double
    let highlightedKind: ShoppingRecommendationKind
    let recommendations: [ShoppingRecommendation]
    let activeItemCount: Int
    let pricedItemCount: Int
    let unresolvedCustomCount: Int
    let loyaltyPricingApplied: Bool

    func recommendation(for kind: ShoppingRecommendationKind) -> ShoppingRecommendation? {
        recommendations.first(where: { $0.kind == kind })
    }

    var highlightedRecommendation: ShoppingRecommendation? {
        recommendation(for: highlightedKind)
    }
}
