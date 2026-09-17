import Foundation
import FirebaseFirestore

enum GroceryItemStatus: String, CaseIterable, Identifiable {
    case active
    case purchased
    case removed

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active:
            return "Attivo"
        case .purchased:
            return "Acquistato"
        case .removed:
            return "Rimosso"
        }
    }

    /// Titolo già risolto, per i componenti che accettano solo `String`.
    var localizedTitle: String {
        String(localized: title)
    }
}

enum GroceryCatalogEnrichmentStatus: String, CaseIterable, Identifiable {
    case queued
    case searching
    case resolved
    case unresolved

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .queued:
            return "In coda"
        case .searching:
            return "Ricerca"
        case .resolved:
            return "Catalogo"
        case .unresolved:
            return "Custom"
        }
    }

    /// Titolo già risolto, per i componenti che accettano solo `String`.
    var localizedTitle: String {
        String(localized: title)
    }

    var isPending: Bool {
        switch self {
        case .queued, .searching:
            return true
        case .resolved, .unresolved:
            return false
        }
    }
}

enum GroceryPreferenceStyle: String, CaseIterable, Identifiable {
    case balanced
    case savings
    case speed

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .balanced:
            return "Bilanciato"
        case .savings:
            return "Risparmio"
        case .speed:
            return "Convenienza"
        }
    }

    /// Titolo già risolto, per i componenti che accettano solo `String`.
    var localizedTitle: String {
        String(localized: title)
    }
}

struct UserGroceryList: Identifiable, Hashable {
    let id: String
    let userId: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }

    static func fromDocument(id: String, data: [String: Any]) -> UserGroceryList? {
        guard let userId = data["userId"] as? String,
              let title = data["title"] as? String else {
            return nil
        }

        let createdAt = groceryDateValue(from: data["createdAt"]) ?? Date()
        let updatedAt = groceryDateValue(from: data["updatedAt"]) ?? createdAt
        let isDefault = data["isDefault"] as? Bool ?? false

        return UserGroceryList(
            id: id,
            userId: userId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDefault: isDefault
        )
    }
}

struct UserGroceryListItem: Identifiable, Hashable {
    let id: String
    let listId: String
    let userId: String
    var rawInputText: String
    var normalizedName: String?
    var productCatalogId: String?
    var quantity: Double
    var unit: String?
    var status: GroceryItemStatus
    var createdAt: Date
    var updatedAt: Date
    var lastPurchasedAt: Date?
    var notes: String?
    var catalogEnrichmentStatus: GroceryCatalogEnrichmentStatus?
    var catalogEnrichmentSource: String?
    var catalogEnrichmentConfidence: Double?
    var catalogEnrichmentUpdatedAt: Date?

    init(
        id: String = UUID().uuidString,
        listId: String,
        userId: String,
        rawInputText: String,
        normalizedName: String? = nil,
        productCatalogId: String? = nil,
        quantity: Double = 1,
        unit: String? = nil,
        status: GroceryItemStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastPurchasedAt: Date? = nil,
        notes: String? = nil,
        catalogEnrichmentStatus: GroceryCatalogEnrichmentStatus? = nil,
        catalogEnrichmentSource: String? = nil,
        catalogEnrichmentConfidence: Double? = nil,
        catalogEnrichmentUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.listId = listId
        self.userId = userId
        self.rawInputText = rawInputText
        self.normalizedName = normalizedName
        self.productCatalogId = productCatalogId
        self.quantity = quantity
        self.unit = unit
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPurchasedAt = lastPurchasedAt
        self.notes = notes
        self.catalogEnrichmentStatus = catalogEnrichmentStatus
        self.catalogEnrichmentSource = catalogEnrichmentSource
        self.catalogEnrichmentConfidence = catalogEnrichmentConfidence
        self.catalogEnrichmentUpdatedAt = catalogEnrichmentUpdatedAt
    }

    var displayName: String {
        normalizedName ?? rawInputText
    }

    var isResolved: Bool {
        productCatalogId != nil
    }

    var effectiveEnrichmentStatus: GroceryCatalogEnrichmentStatus {
        if productCatalogId != nil {
            return .resolved
        }

        return catalogEnrichmentStatus ?? .unresolved
    }

    static func fromDocument(id: String, data: [String: Any]) -> UserGroceryListItem? {
        guard let listId = data["listId"] as? String,
              let userId = data["userId"] as? String,
              let rawInputText = data["rawInputText"] as? String else {
            return nil
        }

        let statusString = data["status"] as? String ?? GroceryItemStatus.active.rawValue
        let quantity = groceryDoubleValue(from: data["quantity"], defaultValue: 1)

        return UserGroceryListItem(
            id: id,
            listId: listId,
            userId: userId,
            rawInputText: rawInputText,
            normalizedName: data["normalizedName"] as? String,
            productCatalogId: data["productCatalogId"] as? String,
            quantity: max(0.5, quantity),
            unit: data["unit"] as? String,
            status: GroceryItemStatus(rawValue: statusString) ?? .active,
            createdAt: groceryDateValue(from: data["createdAt"]) ?? Date(),
            updatedAt: groceryDateValue(from: data["updatedAt"]) ?? Date(),
            lastPurchasedAt: groceryDateValue(from: data["lastPurchasedAt"]),
            notes: data["notes"] as? String,
            catalogEnrichmentStatus: (data["catalogEnrichmentStatus"] as? String).flatMap(GroceryCatalogEnrichmentStatus.init(rawValue:)),
            catalogEnrichmentSource: data["catalogEnrichmentSource"] as? String,
            catalogEnrichmentConfidence: data["catalogEnrichmentConfidence"].flatMap { value in
                let parsedValue = groceryDoubleValue(from: value)
                return parsedValue >= 0 ? parsedValue : nil
            },
            catalogEnrichmentUpdatedAt: groceryDateValue(from: data["catalogEnrichmentUpdatedAt"])
        )
    }
}

struct ProductCatalogItem: Identifiable, Hashable {
    let id: String
    let canonicalName: String
    let brand: String?
    let category: String
    let subcategory: String?
    let sizeLabel: String?
    let aliases: [String]
    let searchableTokens: [String]
    let barcode: String?
    let isActive: Bool

    var searchableCorpus: [String] {
        [canonicalName] + aliases + searchableTokens
    }

    static func fromDocument(id: String, data: [String: Any]) -> ProductCatalogItem? {
        guard let canonicalName = data["canonicalName"] as? String,
              let category = data["category"] as? String else {
            return nil
        }

        return ProductCatalogItem(
            id: id,
            canonicalName: canonicalName,
            brand: data["brand"] as? String,
            category: category,
            subcategory: data["subcategory"] as? String,
            sizeLabel: data["sizeLabel"] as? String,
            aliases: groceryStringArray(from: data["aliases"]),
            searchableTokens: groceryStringArray(from: data["searchableTokens"]),
            barcode: data["barcode"] as? String,
            isActive: data["isActive"] as? Bool ?? true
        )
    }
}

struct GroceryCatalogMatch: Equatable {
    let product: ProductCatalogItem
    let source: String
    let score: Int
}

struct GroceryItemDraft: Equatable {
    var rawInputText: String
    var quantity: Double
    var unit: String?
    var notes: String?

    static let empty = GroceryItemDraft(rawInputText: "", quantity: 1, unit: nil, notes: nil)
}

struct GroceryListSummary: Identifiable, Hashable {
    let list: UserGroceryList
    let itemCount: Int
    let activeCount: Int
    let purchasedCount: Int

    var id: String { list.id }
}

func groceryDateValue(from value: Any?) -> Date? {
    if let timestamp = value as? Timestamp {
        return timestamp.dateValue()
    }

    if let date = value as? Date {
        return date
    }

    if let interval = value as? TimeInterval {
        return Date(timeIntervalSince1970: interval)
    }

    if let number = value as? NSNumber {
        return Date(timeIntervalSince1970: number.doubleValue)
    }

    return nil
}

func groceryDoubleValue(from value: Any?, defaultValue: Double = 0) -> Double {
    if let double = value as? Double {
        return double
    }

    if let int = value as? Int {
        return Double(int)
    }

    if let number = value as? NSNumber {
        return number.doubleValue
    }

    if let string = value as? String, let converted = Double(string.replacingOccurrences(of: ",", with: ".")) {
        return converted
    }

    return defaultValue
}

func groceryStringArray(from value: Any?) -> [String] {
    if let array = value as? [String] {
        return array
    }

    if let array = value as? [Any] {
        return array.compactMap { $0 as? String }
    }

    return []
}
