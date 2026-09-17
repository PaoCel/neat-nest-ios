import Foundation

struct ShoppingList: Identifiable {
    let id: String
    var title: String
    var createdBy: String
    var date: String
    var isCompleted: Bool
    var totalCost: Double
}

struct Product: Identifiable, Codable {
    let id: String
    var name: String
    var addedBy: String
    var isPurchased: Bool
    var category: String
    var cost: Double
}
