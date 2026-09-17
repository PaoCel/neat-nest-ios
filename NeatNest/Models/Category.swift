import Foundation

struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var type: CategoryType
    var color: String
    var familyId: String
    var isActive: Bool

    var categoryId: String {
        return id
    }

    enum CategoryType: String, Codable {
        case income
        case expense
    }

    var dictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "type": type.rawValue,
            "color": color,
            "familyId": familyId,
            "isActive": isActive
        ]
    }
}

extension Category: Hashable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
