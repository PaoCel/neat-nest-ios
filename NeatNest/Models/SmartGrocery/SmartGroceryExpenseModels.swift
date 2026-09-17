import Foundation
import FirebaseFirestore
import SwiftUI

enum ReceiptImportSourceType: String, CaseIterable, Identifiable {
    case demo
    case manual
    case scanned
    case futureDigital

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .demo:
            return "Demo"
        case .manual:
            return "Manuale"
        case .scanned:
            return "Da foto"
        case .futureDigital:
            return "Digitale"
        }
    }

    var localizedTitle: String {
        String(localized: title)
    }
}

enum GrocerySpendingCategory: String, CaseIterable, Identifiable {
    case produce
    case dairy
    case pantry
    case protein
    case bakery
    case beverages
    case household
    case leisure
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .produce:
            return "Ortofrutta"
        case .dairy:
            return "Freschi"
        case .pantry:
            return "Dispensa"
        case .protein:
            return "Proteine"
        case .bakery:
            return "Panetteria"
        case .beverages:
            return "Bevande"
        case .household:
            return "Casa"
        case .leisure:
            return "Tempo libero"
        case .other:
            return "Altro"
        }
    }

    /// Titolo già risolto, per quando serve una `String` (ordinamenti, componenti
    /// che accettano solo stringhe). Nelle view si passa direttamente `title`.
    var localizedTitle: String {
        String(localized: title)
    }

    var iconName: String {
        switch self {
        case .produce:
            return "leaf.fill"
        case .dairy:
            return "snowflake.circle.fill"
        case .pantry:
            return "shippingbox.fill"
        case .protein:
            return "fork.knife.circle.fill"
        case .bakery:
            return "birthday.cake.fill"
        case .beverages:
            return "cup.and.saucer.fill"
        case .household:
            return "house.fill"
        case .leisure:
            return "sparkles.rectangle.stack.fill"
        case .other:
            return "square.grid.2x2.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .produce:
            return .green
        case .dairy:
            return .mint
        case .pantry:
            return .orange
        case .protein:
            return .red
        case .bakery:
            return .brown
        case .beverages:
            return .blue
        case .household:
            return .indigo
        case .leisure:
            return .pink
        case .other:
            return .gray
        }
    }
}

struct ReceiptImport: Identifiable, Hashable {
    let id: String
    let userId: String
    let retailerName: String
    let purchaseDate: Date
    let totalAmount: Double
    let currency: String
    let sourceType: ReceiptImportSourceType
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        retailerName: String,
        purchaseDate: Date,
        totalAmount: Double,
        currency: String = "EUR",
        sourceType: ReceiptImportSourceType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.retailerName = retailerName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.currency = currency
        self.sourceType = sourceType
        self.createdAt = createdAt
    }

    static func fromDocument(id: String, data: [String: Any]) -> ReceiptImport? {
        guard let userId = data["userId"] as? String,
              let retailerName = data["retailerName"] as? String else {
            return nil
        }

        return ReceiptImport(
            id: id,
            userId: userId,
            retailerName: retailerName,
            purchaseDate: groceryDateValue(from: data["purchaseDate"]) ?? Date(),
            totalAmount: groceryDoubleValue(from: data["totalAmount"]),
            currency: data["currency"] as? String ?? "EUR",
            sourceType: ReceiptImportSourceType(rawValue: data["sourceType"] as? String ?? "") ?? .demo,
            createdAt: groceryDateValue(from: data["createdAt"]) ?? Date()
        )
    }
}

struct ReceiptLineItem: Identifiable, Hashable {
    let id: String
    let receiptImportId: String
    let userId: String
    let rawLineText: String
    let normalizedName: String
    let productCatalogId: String?
    let quantity: Double?
    let unitPrice: Double?
    let lineTotal: Double
    let inferredCategory: GrocerySpendingCategory
    let confidence: Double
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        receiptImportId: String,
        userId: String,
        rawLineText: String,
        normalizedName: String,
        productCatalogId: String? = nil,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        lineTotal: Double,
        inferredCategory: GrocerySpendingCategory,
        confidence: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receiptImportId = receiptImportId
        self.userId = userId
        self.rawLineText = rawLineText
        self.normalizedName = normalizedName
        self.productCatalogId = productCatalogId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
        self.inferredCategory = inferredCategory
        self.confidence = confidence
        self.createdAt = createdAt
    }

    var displayName: String {
        normalizedName
    }

    static func fromDocument(id: String, data: [String: Any]) -> ReceiptLineItem? {
        guard let receiptImportId = data["receiptImportId"] as? String,
              let userId = data["userId"] as? String,
              let rawLineText = data["rawLineText"] as? String else {
            return nil
        }

        let quantity = data["quantity"] == nil ? nil : groceryDoubleValue(from: data["quantity"])
        let unitPrice = data["unitPrice"] == nil ? nil : groceryDoubleValue(from: data["unitPrice"])
        let category = GrocerySpendingCategory(rawValue: data["inferredCategory"] as? String ?? "") ?? .other

        return ReceiptLineItem(
            id: id,
            receiptImportId: receiptImportId,
            userId: userId,
            rawLineText: rawLineText,
            normalizedName: data["normalizedName"] as? String ?? rawLineText,
            productCatalogId: data["productCatalogId"] as? String,
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: groceryDoubleValue(from: data["lineTotal"]),
            inferredCategory: category,
            confidence: groceryDoubleValue(from: data["confidence"], defaultValue: 0.5),
            createdAt: groceryDateValue(from: data["createdAt"]) ?? Date()
        )
    }
}

struct PurchaseHistoryEntry: Identifiable, Hashable {
    let receipt: ReceiptImport
    let lineItem: ReceiptLineItem

    var id: String { lineItem.id }
}

struct GrocerySpendingSummary: Equatable {
    let totalSpend: Double
    let receiptCount: Int
    let averageBasket: Double
    let periodStart: Date
    let periodEnd: Date
}

struct GrocerySpendingCategorySummary: Identifiable, Equatable {
    let category: GrocerySpendingCategory
    let amount: Double
    let itemCount: Int
    let share: Double

    var id: String { category.id }
}

struct DemoReceiptTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let retailerName: String
    let purchaseDate: Date
    let currency: String
    let lineItems: [DemoReceiptTemplateLine]
    let accentColorName: String

    var estimatedTotal: Double {
        lineItems.reduce(0) { $0 + $1.lineTotal }
    }

    var previewLabels: [String] {
        Array(lineItems.prefix(3).map(\.rawLineText))
    }
}

struct DemoReceiptTemplateLine: Identifiable, Hashable {
    let id: String
    let rawLineText: String
    let quantity: Double?
    let unitPrice: Double?
    let lineTotal: Double

    init(
        id: String = UUID().uuidString,
        rawLineText: String,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        lineTotal: Double
    ) {
        self.id = id
        self.rawLineText = rawLineText
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
    }
}

struct ReceiptReconciliationHint: Equatable {
    let matchedItemCount: Int
    let listTitles: [String]

    /// Il plurale non si scrive a mano: molte lingue hanno più di due forme.
    /// La variazione sta nello String Catalog.
    var title: String {
        String(
            localized: "receipt.reconciliation.matchedItems",
            defaultValue: "\(matchedItemCount) articoli erano già nelle tue liste"
        )
    }

    var message: String {
        guard let firstListTitle = listTitles.first else {
            return "Li mostriamo come indizio leggero per la riconciliazione della spesa."
        }

        if listTitles.count == 1 {
            return "Controlla \(firstListTitle): alcuni articoli importati coincidono con elementi gia attivi."
        }

        return "Controlla \(firstListTitle) e altre \(listTitles.count - 1) liste: alcuni articoli importati coincidono con elementi gia attivi."
    }
}

struct ReceiptImportResult: Equatable {
    let receipt: ReceiptImport
    let lineItems: [ReceiptLineItem]
    let matchedLineCount: Int
    let unresolvedLineCount: Int
    let reconciliationHint: ReceiptReconciliationHint?
}
