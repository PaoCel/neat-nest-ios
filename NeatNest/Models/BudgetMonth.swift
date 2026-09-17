import Foundation

struct BudgetMonth: Identifiable, Codable {
    let id: String
    var name: String
    let dateRange: DateRange
    var categoryBudgets: [CategoryBudget]
    var totalPlannedIncome: Double
    var totalPlannedExpenses: Double
    var totalActualIncome: Double
    var totalActualExpenses: Double
    var familyId: String

    var plannedBalance: Double {
        totalPlannedIncome - totalPlannedExpenses
    }

    var actualBalance: Double {
        totalActualIncome - totalActualExpenses
    }

    var transactions: [Transaction] {
        []
    }

    var dictionary: [String: Any] {
        return [
            "name": name,
            "dateRange": dateRange.dictionary,
            "categoryBudgets": categoryBudgets.map { $0.dictionary },
            "totalPlannedIncome": totalPlannedIncome,
            "totalPlannedExpenses": totalPlannedExpenses,
            "totalActualIncome": totalActualIncome,
            "totalActualExpenses": totalActualExpenses,
            "familyId": familyId
        ]
    }
}

struct CategoryBudget: Identifiable, Codable {
    let id: String
    var categoryId: String
    var plannedAmount: Double
    var actualAmount: Double

    var dictionary: [String: Any] {
        return [
            "id": id,
            "categoryId": categoryId,
            "plannedAmount": plannedAmount,
            "actualAmount": actualAmount
        ]
    }
}

struct DateRange: Codable {
    let startDate: Date
    let endDate: Date

    var dictionary: [String: Any] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return [
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate)
        ]
    }

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        return normalizedDate >= normalizedStart && normalizedDate <= normalizedEnd
    }
}

struct BudgetData: Identifiable {
    let id = UUID()
    let categoryName: String
    let amount: Double
}
