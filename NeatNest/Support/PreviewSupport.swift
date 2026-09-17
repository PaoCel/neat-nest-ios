import Foundation
import SwiftUI

struct RegistrationPreviewSeed {
    var email: String = "paolo@example.com"
    var password: String = "Casa2026!"
    var confirmPassword: String = "Casa2026!"
    var userName: String = "Paolo"
    var selectedGender: String = "Maschio"
    var familyCode: String = "NIDO2026"
    var familyCodeExists: Bool? = false
    var errorMessage: String? = nil
}

struct CompleteProfilePreviewSeed {
    var email: String = "paolo@example.com"
    var userName: String = "Paolo"
    var selectedGender: String = "Maschio"
    var familyCode: String = "NIDO2026"
    var familyCodeExists: Bool? = false
    var errorMessage: String? = nil
}

final class PreviewUserSession: UserSession {
    private let previewCurrentUserId: String?

    override var currentUserId: String? {
        previewCurrentUserId
    }

    init(
        userId: String = PreviewSupport.previewUserId,
        userName: String = "Paolo",
        gender: String = "Maschio",
        familyId: String = "NIDO2026",
        isLoggedIn: Bool = true,
        sessionErrorMessage: String? = nil
    ) {
        self.previewCurrentUserId = userId
        super.init()
        currentUserName = userName
        currentUserGender = gender
        self.familyId = familyId
        self.isLoggedIn = isLoggedIn
        self.sessionErrorMessage = sessionErrorMessage
    }
}

enum PreviewSupport {
    static let previewUserId = "preview-user"

    static func makeUserSession(
        userName: String = "Paolo",
        gender: String = "Maschio",
        familyId: String = "NIDO2026",
        isLoggedIn: Bool = true,
        sessionErrorMessage: String? = nil
    ) -> PreviewUserSession {
        PreviewUserSession(
            userId: previewUserId,
            userName: userName,
            gender: gender,
            familyId: familyId,
            isLoggedIn: isLoggedIn,
            sessionErrorMessage: sessionErrorMessage
        )
    }

    static var registrationSeed: RegistrationPreviewSeed {
        RegistrationPreviewSeed()
    }

    static var completeProfileSeed: CompleteProfilePreviewSeed {
        CompleteProfilePreviewSeed(
            email: "paolo.social@example.com",
            userName: "Paolo",
            selectedGender: "Maschio",
            familyCode: "NIDO2026",
            familyCodeExists: false,
            errorMessage: nil
        )
    }

    static var now: Date {
        Date()
    }

    static var defaultList: UserGroceryList {
        UserGroceryList(
            id: "preview-list-main",
            userId: previewUserId,
            title: "Spesa settimanale",
            createdAt: Calendar.current.date(byAdding: .day, value: -21, to: now) ?? now,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
            isDefault: true
        )
    }

    static var dinnerList: UserGroceryList {
        UserGroceryList(
            id: "preview-list-dinner",
            userId: previewUserId,
            title: "Cena amici",
            createdAt: Calendar.current.date(byAdding: .day, value: -8, to: now) ?? now,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
            isDefault: false
        )
    }

    static var catalog: [ProductCatalogItem] {
        SeededProductCatalog.items
    }

    static var activeItems: [UserGroceryListItem] {
        [
            UserGroceryListItem(
                id: "preview-item-latte",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "latte Arborea",
                normalizedName: "Latte Arborea",
                productCatalogId: "latte-arborea",
                quantity: 2,
                unit: "pz",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .hour, value: -1, to: now)
            ),
            UserGroceryListItem(
                id: "preview-item-pasta",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "pasta Barilla",
                normalizedName: "Pasta Barilla",
                productCatalogId: "pasta-barilla",
                quantity: 2,
                unit: "pz",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -6, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: "Per la cena di sabato",
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .hour, value: -6, to: now)
            ),
            UserGroceryListItem(
                id: "preview-item-zucchine",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "zucchine",
                normalizedName: "Zucchine",
                productCatalogId: "zucchine",
                quantity: 1,
                unit: "kg",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -10, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .hour, value: -10, to: now)
            ),
            UserGroceryListItem(
                id: "preview-item-yogurt",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "yogurt greco",
                normalizedName: "Yogurt greco",
                productCatalogId: "yogurt-greco",
                quantity: 4,
                unit: "pz",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -14, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .hour, value: -14, to: now)
            ),
            UserGroceryListItem(
                id: "preview-item-oro-ciok",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "oro ciok",
                normalizedName: nil,
                productCatalogId: nil,
                quantity: 1,
                unit: "pz",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .minute, value: -25, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: "Ancora da verificare",
                catalogEnrichmentStatus: .unresolved,
                catalogEnrichmentSource: "custom",
                catalogEnrichmentConfidence: nil,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .minute, value: -25, to: now)
            )
        ]
    }

    static var purchasedItems: [UserGroceryListItem] {
        [
            UserGroceryListItem(
                id: "preview-item-tonno",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "tonno all'olio",
                normalizedName: "Tonno all'olio",
                productCatalogId: "tonno-allolio",
                quantity: 2,
                unit: "pz",
                status: .purchased,
                createdAt: Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                lastPurchasedAt: Calendar.current.date(byAdding: .day, value: -2, to: now),
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .day, value: -2, to: now)
            )
        ]
    }

    static var removedItems: [UserGroceryListItem] {
        [
            UserGroceryListItem(
                id: "preview-item-riso",
                listId: defaultList.id,
                userId: previewUserId,
                rawInputText: "riso basmati",
                normalizedName: "Riso basmati",
                productCatalogId: "riso-basmati",
                quantity: 1,
                unit: "pz",
                status: .removed,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)
            )
        ]
    }

    static var dinnerListItems: [UserGroceryListItem] {
        [
            UserGroceryListItem(
                id: "preview-item-pane-dinner",
                listId: dinnerList.id,
                userId: previewUserId,
                rawInputText: "pane",
                normalizedName: "Pane",
                productCatalogId: "pane",
                quantity: 1,
                unit: "pz",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)
            ),
            UserGroceryListItem(
                id: "preview-item-pollo-dinner",
                listId: dinnerList.id,
                userId: previewUserId,
                rawInputText: "petto di pollo",
                normalizedName: "Petto di pollo",
                productCatalogId: "petto-di-pollo",
                quantity: 1,
                unit: "kg",
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .hour, value: -20, to: now) ?? now,
                lastPurchasedAt: nil,
                notes: nil,
                catalogEnrichmentStatus: .resolved,
                catalogEnrichmentSource: "catalog",
                catalogEnrichmentConfidence: 1,
                catalogEnrichmentUpdatedAt: Calendar.current.date(byAdding: .hour, value: -20, to: now)
            )
        ]
    }

    static var allItems: [UserGroceryListItem] {
        activeItems + purchasedItems + removedItems + dinnerListItems
    }

    static var listSummaries: [GroceryListSummary] {
        [
            GroceryListSummary(
                list: defaultList,
                itemCount: 6,
                activeCount: 5,
                purchasedCount: 1
            ),
            GroceryListSummary(
                list: dinnerList,
                itemCount: 2,
                activeCount: 2,
                purchasedCount: 0
            )
        ]
    }

    static var upcomingSuggestions: [ProductCatalogItem] {
        catalog.filter { product in
            !Set(activeItems.compactMap(\.productCatalogId)).contains(product.id)
        }
    }

    static var reactivationSuggestion: GroceryReactivationSuggestion {
        GroceryReactivationSuggestion(
            id: "preview-suggestion",
            matchedProductName: "Tonno all'olio",
            previousItemName: "Tonno all'olio",
            lastPurchasedAt: Calendar.current.date(byAdding: .day, value: -2, to: now)
        )
    }

    static var voiceProcessedResult: SmartGroceryVoiceProcessedResult {
        SmartGroceryVoiceProcessedResult(
            listId: defaultList.id,
            listTitle: defaultList.title,
            itemName: "Coca Cola Zero",
            rawInputText: "Coca Cola Zero",
            createdAt: Calendar.current.date(byAdding: .minute, value: -8, to: now) ?? now,
            suggestion: nil
        )
    }

    static var pricingRetailers: [Retailer] {
        [
            Retailer(id: "esselunga-preview", name: "Esselunga", cityArea: "Milano Porta Romana", isActive: true),
            Retailer(id: "lidl-preview", name: "Lidl", cityArea: "Milano Isola", isActive: true),
            Retailer(id: "conad-preview", name: "Conad City", cityArea: "Milano Navigli", isActive: true)
        ]
    }

    static var pricingData: [RetailerProductPrice] {
        [
            RetailerProductPrice(
                id: "price-esselunga-latte",
                retailerId: "esselunga-preview",
                productCatalogId: "latte-arborea",
                basePrice: 1.89,
                promoPrice: 1.69,
                loyaltyPrice: 1.59,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.95
            ),
            RetailerProductPrice(
                id: "price-lidl-latte",
                retailerId: "lidl-preview",
                productCatalogId: "latte-arborea",
                basePrice: 1.79,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.91
            ),
            RetailerProductPrice(
                id: "price-conad-latte",
                retailerId: "conad-preview",
                productCatalogId: "latte-arborea",
                basePrice: 1.99,
                promoPrice: 1.79,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -6, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.88
            ),
            RetailerProductPrice(
                id: "price-esselunga-pasta",
                retailerId: "esselunga-preview",
                productCatalogId: "pasta-barilla",
                basePrice: 1.49,
                promoPrice: 1.09,
                loyaltyPrice: 0.99,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.96
            ),
            RetailerProductPrice(
                id: "price-lidl-pasta",
                retailerId: "lidl-preview",
                productCatalogId: "pasta-barilla",
                basePrice: 1.19,
                promoPrice: 0.99,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -5, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.93
            ),
            RetailerProductPrice(
                id: "price-conad-pasta",
                retailerId: "conad-preview",
                productCatalogId: "pasta-barilla",
                basePrice: 1.59,
                promoPrice: 1.19,
                loyaltyPrice: 1.09,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -7, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.89
            ),
            RetailerProductPrice(
                id: "price-esselunga-zucchine",
                retailerId: "esselunga-preview",
                productCatalogId: "zucchine",
                basePrice: 1.58,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -3, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.94
            ),
            RetailerProductPrice(
                id: "price-lidl-zucchine",
                retailerId: "lidl-preview",
                productCatalogId: "zucchine",
                basePrice: 1.19,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.92
            ),
            RetailerProductPrice(
                id: "price-conad-zucchine",
                retailerId: "conad-preview",
                productCatalogId: "zucchine",
                basePrice: 1.49,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -5, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.88
            ),
            RetailerProductPrice(
                id: "price-esselunga-yogurt",
                retailerId: "esselunga-preview",
                productCatalogId: "yogurt-greco",
                basePrice: 1.39,
                promoPrice: nil,
                loyaltyPrice: 1.19,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.93
            ),
            RetailerProductPrice(
                id: "price-lidl-yogurt",
                retailerId: "lidl-preview",
                productCatalogId: "yogurt-greco",
                basePrice: 0.99,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.93
            ),
            RetailerProductPrice(
                id: "price-conad-yogurt",
                retailerId: "conad-preview",
                productCatalogId: "yogurt-greco",
                basePrice: 1.29,
                promoPrice: nil,
                loyaltyPrice: nil,
                currency: "EUR",
                isAvailable: true,
                lastUpdatedAt: Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now,
                sourceType: .provider,
                sourceConfidence: 0.87
            )
        ]
    }

    static var letsShopPreparation: LetsShopPreparationSummary {
        LetsShopPreparationSummary(
            list: defaultList,
            activeItems: activeItems,
            resolvedCount: 4,
            unresolvedCount: 1,
            pricedCount: 4,
            retailers: pricingRetailers,
            latestPriceUpdate: pricingData.map(\.lastUpdatedAt).max()
        )
    }

    static var recommendationSet: ShoppingRecommendationSet {
        ShoppingRecommendationEngine().buildRecommendations(
            for: defaultList,
            activeItems: activeItems,
            catalog: catalog,
            retailers: pricingRetailers,
            prices: pricingData,
            preferenceValue: 52,
            considerLoyaltyPricing: true
        )
    }

    static var receiptTemplates: [DemoReceiptTemplate] {
        [
            DemoReceiptTemplate(
                id: "preview-esselunga-template",
                title: "Spesa settimanale",
                retailerName: "Esselunga",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "latte Arborea", quantity: 2, unitPrice: 1.89, lineTotal: 3.78),
                    DemoReceiptTemplateLine(rawLineText: "yogurt greco", quantity: 2, unitPrice: 1.79, lineTotal: 3.58),
                    DemoReceiptTemplateLine(rawLineText: "Monopoly", quantity: 1, unitPrice: 24.90, lineTotal: 24.90)
                ],
                accentColorName: "green"
            ),
            DemoReceiptTemplate(
                id: "preview-lidl-template",
                title: "Spesa smart",
                retailerName: "Lidl",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "tonno all'olio", quantity: 2, unitPrice: 2.15, lineTotal: 4.30),
                    DemoReceiptTemplateLine(rawLineText: "pane", quantity: 1, unitPrice: 1.59, lineTotal: 1.59),
                    DemoReceiptTemplateLine(rawLineText: "detersivo piatti", quantity: 1, unitPrice: 2.79, lineTotal: 2.79)
                ],
                accentColorName: "blue"
            ),
            DemoReceiptTemplate(
                id: "preview-conad-template",
                title: "Cena veloce",
                retailerName: "Conad",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "pane", quantity: 1, unitPrice: 1.89, lineTotal: 1.89),
                    DemoReceiptTemplateLine(rawLineText: "latte senza lattosio", quantity: 1, unitPrice: 2.09, lineTotal: 2.09),
                    DemoReceiptTemplateLine(rawLineText: "zucchine", quantity: 1, unitPrice: 2.10, lineTotal: 2.10)
                ],
                accentColorName: "orange"
            )
        ]
    }

    static var receiptImports: [ReceiptImport] {
        [
            ReceiptImport(
                id: "preview-receipt-esselunga",
                userId: previewUserId,
                retailerName: "Esselunga",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                totalAmount: 32.26,
                currency: "EUR",
                sourceType: .demo,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            ReceiptImport(
                id: "preview-receipt-lidl",
                userId: previewUserId,
                retailerName: "Lidl",
                purchaseDate: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
                totalAmount: 8.68,
                currency: "EUR",
                sourceType: .demo,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            )
        ]
    }

    static var receiptLineItems: [ReceiptLineItem] {
        [
            ReceiptLineItem(
                id: "preview-line-latte",
                receiptImportId: "preview-receipt-esselunga",
                userId: previewUserId,
                rawLineText: "latte Arborea",
                normalizedName: "Latte Arborea",
                productCatalogId: "latte-arborea",
                quantity: 2,
                unitPrice: 1.89,
                lineTotal: 3.78,
                inferredCategory: .dairy,
                confidence: 0.98,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            ReceiptLineItem(
                id: "preview-line-yogurt",
                receiptImportId: "preview-receipt-esselunga",
                userId: previewUserId,
                rawLineText: "yogurt greco",
                normalizedName: "Yogurt greco",
                productCatalogId: "yogurt-greco",
                quantity: 2,
                unitPrice: 1.79,
                lineTotal: 3.58,
                inferredCategory: .dairy,
                confidence: 0.96,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            ReceiptLineItem(
                id: "preview-line-monopoly",
                receiptImportId: "preview-receipt-esselunga",
                userId: previewUserId,
                rawLineText: "Monopoly",
                normalizedName: "Monopoly",
                productCatalogId: nil,
                quantity: 1,
                unitPrice: 24.90,
                lineTotal: 24.90,
                inferredCategory: .leisure,
                confidence: 0.91,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            ReceiptLineItem(
                id: "preview-line-tonno",
                receiptImportId: "preview-receipt-lidl",
                userId: previewUserId,
                rawLineText: "tonno all'olio",
                normalizedName: "Tonno all'olio",
                productCatalogId: "tonno-allolio",
                quantity: 2,
                unitPrice: 2.15,
                lineTotal: 4.30,
                inferredCategory: .pantry,
                confidence: 0.97,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            ),
            ReceiptLineItem(
                id: "preview-line-detersivo",
                receiptImportId: "preview-receipt-lidl",
                userId: previewUserId,
                rawLineText: "detersivo piatti",
                normalizedName: "Detersivo piatti",
                productCatalogId: nil,
                quantity: 1,
                unitPrice: 2.79,
                lineTotal: 2.79,
                inferredCategory: .household,
                confidence: 0.88,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            ),
            ReceiptLineItem(
                id: "preview-line-pane",
                receiptImportId: "preview-receipt-lidl",
                userId: previewUserId,
                rawLineText: "pane",
                normalizedName: "Pane",
                productCatalogId: "pane",
                quantity: 1,
                unitPrice: 1.59,
                lineTotal: 1.59,
                inferredCategory: .bakery,
                confidence: 0.95,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            )
        ]
    }

    static var purchaseHistory: [PurchaseHistoryEntry] {
        let receiptsById = Dictionary(uniqueKeysWithValues: receiptImports.map { ($0.id, $0) })
        return receiptLineItems.compactMap { lineItem in
            guard let receipt = receiptsById[lineItem.receiptImportId] else { return nil }
            return PurchaseHistoryEntry(receipt: receipt, lineItem: lineItem)
        }
        .sorted { lhs, rhs in
            if lhs.receipt.purchaseDate != rhs.receipt.purchaseDate {
                return lhs.receipt.purchaseDate > rhs.receipt.purchaseDate
            }
            return lhs.lineItem.lineTotal > rhs.lineItem.lineTotal
        }
    }

    static var spendingSummary: GrocerySpendingSummary {
        GrocerySpendingSummary(
            totalSpend: 40.94,
            receiptCount: 2,
            averageBasket: 20.47,
            periodStart: Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now,
            periodEnd: now
        )
    }

    static var categorySummaries: [GrocerySpendingCategorySummary] {
        [
            GrocerySpendingCategorySummary(category: .leisure, amount: 24.90, itemCount: 1, share: 24.90 / 40.94),
            GrocerySpendingCategorySummary(category: .dairy, amount: 7.36, itemCount: 2, share: 7.36 / 40.94),
            GrocerySpendingCategorySummary(category: .pantry, amount: 4.30, itemCount: 1, share: 4.30 / 40.94),
            GrocerySpendingCategorySummary(category: .household, amount: 2.79, itemCount: 1, share: 2.79 / 40.94),
            GrocerySpendingCategorySummary(category: .bakery, amount: 1.59, itemCount: 1, share: 1.59 / 40.94)
        ]
    }

    static var lastImportResult: ReceiptImportResult {
        ReceiptImportResult(
            receipt: receiptImports[0],
            lineItems: Array(receiptLineItems.prefix(3)),
            matchedLineCount: 2,
            unresolvedLineCount: 1,
            reconciliationHint: ReceiptReconciliationHint(
                matchedItemCount: 2,
                listTitles: [defaultList.title]
            )
        )
    }

    @MainActor
    static func makeVoiceManager() -> SmartGroceryVoiceManager {
        SmartGroceryVoiceManager(previewResult: voiceProcessedResult)
    }

    @MainActor
    static func makeSmartGroceryHomeViewModel() -> SmartGroceryHomeViewModel {
        SmartGroceryHomeViewModel(
            previewListSummaries: listSummaries,
            recentItems: Array(allItems.filter { $0.status != .removed }.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)),
            upcomingSuggestions: Array(upcomingSuggestions.prefix(6))
        )
    }

    @MainActor
    static func makeGroceryListsViewModel() -> GroceryListsViewModel {
        GroceryListsViewModel(
            previewListSummaries: listSummaries,
            allItems: allItems
        )
    }

    @MainActor
    static func makeGroceryListDetailViewModel() -> GroceryListDetailViewModel {
        GroceryListDetailViewModel(
            previewActiveItems: activeItems,
            purchasedItems: purchasedItems,
            removedItems: removedItems,
            catalogSuggestions: Array(upcomingSuggestions.prefix(6)),
            latestSuggestion: reactivationSuggestion
        )
    }

    @MainActor
    static func makeLetsShopPreferenceViewModel() -> LetsShopPreferenceViewModel {
        LetsShopPreferenceViewModel(
            previewList: defaultList,
            preparation: letsShopPreparation,
            recommendationSet: recommendationSet,
            preferenceValue: recommendationSet.preferenceValue
        )
    }

    @MainActor
    static func makeSmartGrocerySpendingViewModel() -> SmartGrocerySpendingViewModel {
        SmartGrocerySpendingViewModel(
            previewSummary: spendingSummary,
            categorySummaries: categorySummaries,
            recentReceipts: receiptImports,
            recentPurchases: purchaseHistory,
            templates: receiptTemplates,
            lastImportResult: lastImportResult
        )
    }
}
