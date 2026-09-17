import Foundation

struct GroceryReactivationSuggestion: Identifiable, Equatable {
    let id: String
    let matchedProductName: String
    let previousItemName: String
    let lastPurchasedAt: Date?

    var title: String {
        String(
            localized: "grocery.reactivation.title",
            defaultValue: "Hai già comprato questo prodotto in passato"
        )
    }
}

struct GroceryItemCreationResult {
    let item: UserGroceryListItem
    let suggestion: GroceryReactivationSuggestion?
}

struct PendingSmartGroceryVoiceRequest: Codable, Equatable {
    let id: String
    let rawInputText: String
    let createdAt: Date

    init(id: String = UUID().uuidString, rawInputText: String, createdAt: Date = Date()) {
        self.id = id
        self.rawInputText = rawInputText
        self.createdAt = createdAt
    }
}

struct SmartGroceryVoiceProcessedResult: Identifiable, Equatable {
    let id: String
    let listId: String
    let listTitle: String
    let itemName: String
    let rawInputText: String
    let createdAt: Date
    let suggestion: GroceryReactivationSuggestion?

    init(
        id: String = UUID().uuidString,
        listId: String,
        listTitle: String,
        itemName: String,
        rawInputText: String,
        createdAt: Date = Date(),
        suggestion: GroceryReactivationSuggestion?
    ) {
        self.id = id
        self.listId = listId
        self.listTitle = listTitle
        self.itemName = itemName
        self.rawInputText = rawInputText
        self.createdAt = createdAt
        self.suggestion = suggestion
    }
}
