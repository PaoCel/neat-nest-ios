import SwiftUI
import FirebaseDatabase

@Observable
final class BudgetHomeViewModel {
    var budgetManager: BudgetManager
    var selectedBudgetId: String?

    var currentMonth: BudgetMonth? {
        budgetManager.currentMonth
    }

    var recentTransactions: [Transaction] {
        Array(budgetManager.transactions.sorted { $0.date > $1.date }.prefix(5))
    }

    init(userSession: UserSession) {
        self.budgetManager = BudgetManager(userSession: userSession)
    }

    var depositBalance: Double? {
        guard let depositCategory = budgetManager.categories.first(where: { $0.name.lowercased() == "deposito" || $0.name.lowercased() == "salvadanaio" }) else {
            return nil
        }

        let depositTransactions = budgetManager.transactions.filter { $0.categoryId == depositCategory.id }
        let balance = depositTransactions.reduce(0) { $0 + $1.amount }
        return balance
    }

    func navigateToBudgetDetails(budgetMonthId: String) {
        self.selectedBudgetId = budgetMonthId
    }
}
