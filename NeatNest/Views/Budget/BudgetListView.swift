import SwiftUI

// MARK: - Budget List View
struct BudgetListView: View {
    @ObservedObject var budgetManager: BudgetManager
    @State private var showingAddBudget = false

    private var sortedMonths: [BudgetMonth] {
        budgetManager.budgetMonths.sorted { first, second in
            first.dateRange.startDate > second.dateRange.startDate
        }
    }

    var body: some View {
        List {
            ForEach(sortedMonths) { month in
                NavigationLink(
                    destination: MonthDetailView(
                        budgetManager: budgetManager,
                        budgetMonthId: month.id
                    )
                ) {
                    BudgetMonthListItem(budgetMonth: month, budgetManager: budgetManager)
                }
            }
        }
        .navigationTitle("Budget Mensili")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddBudget = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetMonthView(budgetManager: budgetManager)
        }
    }
}

// MARK: - Budget Month List Item
struct BudgetMonthListItem: View {
    let budgetMonth: BudgetMonth
    let budgetManager: BudgetManager

    private var actualIncome: Double {
        budgetManager.actualIncome(for: budgetMonth)
    }

    private var actualExpenses: Double {
        budgetManager.actualExpenses(for: budgetMonth)
    }

    private var actualBalance: Double {
        budgetManager.actualBalance(for: budgetMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budgetMonth.name)
                    .font(.headline)
                Spacer()
                Text(getStatusText())
                    .font(.caption)
                    .foregroundColor(getStatusColor())
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Entrate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(actualIncome, format: .euro)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Uscite")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(actualExpenses, format: .euro)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func getStatusText() -> String {
        if actualBalance >= 0 {
            return "In positivo"
        } else {
            return "In negativo"
        }
    }

    private func getStatusColor() -> Color {
        actualBalance >= 0 ? .green : .red
    }
}
