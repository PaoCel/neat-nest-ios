import SwiftUI
import Charts

struct CurrentMonthSummaryView: View {
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
        VStack(spacing: 16) {
            Text(formatDateRange(budgetMonth.dateRange))
                .font(.subheadline)
                .foregroundColor(.secondary)
            let chartData = prepareChartData()

            VStack(spacing: 12) {
                HStack {
                    Text("Saldo Attuale")
                        .font(.headline)
                    Spacer()
                    Text(actualBalance, format: .euro)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(actualBalance >= 0 ? .green : .red)
                }

                ProgressRow(
                    title: "Entrate",
                    current: actualIncome,
                    target: budgetMonth.totalPlannedIncome,
                    color: .blue
                )

                ProgressRow(
                    title: "Uscite",
                    current: actualExpenses,
                    target: budgetMonth.totalPlannedExpenses,
                    color: .red
                )
            }
            if #available(iOS 17.0, *) {
                BudgetPieChartView(budgetData: chartData)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func prepareChartData() -> [BudgetData] {
        var data: [BudgetData] = []
        let categories = budgetManager.categories

        for categoryBudget in budgetMonth.categoryBudgets {
            if let category = categories.first(where: { $0.id == categoryBudget.categoryId }) {
                let amount = budgetManager.actualAmount(for: category, in: budgetMonth)
                if amount != 0 {
                    data.append(BudgetData(categoryName: category.name, amount: amount))
                }
            }
        }
        return data
    }

    private func formatDateRange(_ range: DateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: range.startDate)
    }
}

// MARK: - Progress Row
struct ProgressRow: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(current, format: .euro) / \(target, format: .euro)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

@available(iOS 17.0, *)
struct BudgetPieChartView: View {
    let budgetData: [BudgetData]

    var body: some View {
        Chart(budgetData) { data in
            if #available(iOS 17.0, *) {
                SectorMark(
                    angle: .value("Amount", data.amount),
                    innerRadius: .ratio(0.5)
                )
                .foregroundStyle(by: .value("Category", data.categoryName))
            }
        }
        .chartLegend(.visible)
        .frame(height: 300)
    }
}

struct MonthSummaryCard: View {
    let budgetMonth: BudgetMonth
    let budgetManager: BudgetManager

    private func formatRange(_ range: DateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(formatRange(budgetMonth.dateRange))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("Saldo")
                Spacer()
                Text(budgetManager.actualBalance(for: budgetMonth), format: .euro)
                    .font(.headline)
                    .foregroundColor(budgetManager.actualBalance(for: budgetMonth) >= 0 ? .green : .red)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
