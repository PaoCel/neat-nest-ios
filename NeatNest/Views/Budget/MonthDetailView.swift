import SwiftUI
import FirebaseDatabase
import Combine

struct MonthDetailView: View {
    @ObservedObject var budgetManager: BudgetManager
    let budgetMonthId: String

    @State private var budgetMonth: BudgetMonth?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var isEditing = false
    @State private var selectedTab = 0
    @State private var selectedView = "planned"

    @State private var editingName: String = ""
    @State private var editingStartDate: Date = Date()
    @State private var editingEndDate: Date = Date()
    @State private var editingCategoryBudgets: [CategoryBudget] = []

    private var relevantTransactions: [Transaction] {
        return budgetManager.monthTransactions
    }

    private var incomeCategories: [Category] {
        budgetManager.categories.filter { $0.type == .income }
    }

    private var expenseCategories: [Category] {
        budgetManager.categories.filter { $0.type == .expense }
    }

    private var currentActualIncome: Double {
        relevantTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var currentActualExpenses: Double {
        relevantTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                Text("Errore: \(error.localizedDescription)")
            } else if let month = budgetMonth {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Text(formatDateRange(month.dateRange))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            TotalCard(
                                title: "Entrate",
                                amount: selectedView == "actual" ? currentActualIncome : month.totalPlannedIncome,
                                color: .green
                            )

                            TotalCard(
                                title: "Uscite",
                                amount: selectedView == "actual" ? currentActualExpenses : month.totalPlannedExpenses,
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))

                    if isEditing {
                        editModeContent
                    } else {
                        viewModeContent
                    }
                }
                .navigationTitle(month.name)
                .navigationBarItems(trailing: editButton)
            } else {
                Text("Budget non trovato")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadData()
            if budgetManager.categories.isEmpty {
                budgetManager.loadCategories()
            }
        }
    }

    private var editModeContent: some View {
        Form {
            Section(header: Text("Dettagli")) {
                TextField("Nome mese", text: $editingName)
                DatePicker("Data inizio", selection: $editingStartDate, displayedComponents: .date)
                DatePicker("Data fine", selection: $editingEndDate, displayedComponents: .date)
            }

            Section(header: Text("Budget Categorie")) {
                let categories = selectedTab == 0 ? incomeCategories : expenseCategories
                ForEach(categories) { category in
                    HStack {
                        Text(category.name)
                            .font(.headline)
                        Spacer()
                        TextField("Importo", value: bindingForCategory(category), formatter: NumberFormatter.currency)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
        }
    }

    private var viewModeContent: some View {
        VStack(spacing: 0) {
            Picker("Tipo", selection: $selectedTab) {
                Text("Entrate").tag(0)
                Text("Uscite").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Picker("Vista", selection: $selectedView) {
                Text("Budget Previsto").tag("planned")
                Text("Valori Effettivi").tag("actual")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            List {
                let categories = selectedTab == 0 ? incomeCategories : expenseCategories
                ForEach(categories) { category in
                    CategoryRowAmount(
                        category: category,
                        plannedAmount: plannedAmount(for: category),
                        actualAmount: actualAmount(for: category),
                        showingActual: selectedView == "actual"
                    )
                }
            }
        }
    }

    private var editButton: some View {
        Button(action: {
            if isEditing {
                saveChanges()
            }
            isEditing.toggle()
        }) {
            Text(isEditing ? "Salva" : "Modifica")
        }
    }

    private func loadData() {
        isLoading = true

        budgetManager.loadBudgetMonth(id: budgetMonthId)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { loadedMonth in
                    self.budgetMonth = loadedMonth
                    if let month = loadedMonth {
                        budgetManager.observeTransactionsForMonth(month)
                        initializeEditingValues()
                    }
                }
            )
            .store(in: &budgetManager.cancellables)
    }

    private func initializeEditingValues() {
        guard let month = budgetMonth else { return }
        editingName = month.name
        editingStartDate = month.dateRange.startDate
        editingEndDate = month.dateRange.endDate
        editingCategoryBudgets = month.categoryBudgets

        let allCategories = budgetManager.categories
        for category in allCategories {
            if !editingCategoryBudgets.contains(where: { $0.categoryId == category.id }) {
                let newBudget = CategoryBudget(
                    id: UUID().uuidString,
                    categoryId: category.id,
                    plannedAmount: 0,
                    actualAmount: 0
                )
                editingCategoryBudgets.append(newBudget)
            }
        }
    }

    private func saveChanges() {
        guard let currentMonth = budgetMonth else { return }

        let updatedBudgetMonth = BudgetMonth(
            id: currentMonth.id,
            name: editingName,
            dateRange: DateRange(startDate: editingStartDate, endDate: editingEndDate),
            categoryBudgets: editingCategoryBudgets,
            totalPlannedIncome: calculateTotalPlanned(for: .income),
            totalPlannedExpenses: calculateTotalPlanned(for: .expense),
            totalActualIncome: currentActualIncome,
            totalActualExpenses: currentActualExpenses,
            familyId: currentMonth.familyId
        )

        budgetManager.updateBudgetMonth(updatedBudgetMonth)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.error = error
                    } else {
                        self.budgetMonth = updatedBudgetMonth
                        self.isEditing = false
                    }
                },
                receiveValue: { }
            )
            .store(in: &budgetManager.cancellables)
    }

    private func calculateTotalPlanned(for type: Category.CategoryType) -> Double {
        let categories = type == .income ? incomeCategories : expenseCategories
        let categoryIds = categories.map { $0.id }
        return editingCategoryBudgets
            .filter { categoryIds.contains($0.categoryId) }
            .reduce(0) { $0 + $1.plannedAmount }
    }

    private func plannedAmount(for category: Category) -> Double {
        editingCategoryBudgets
            .first { $0.categoryId == category.id }?
            .plannedAmount ?? 0
    }

    private func actualAmount(for category: Category) -> Double {
        let total = relevantTransactions
            .filter { $0.categoryId == category.id }
            .reduce(0) { $0 + $1.amount }

        return category.type == .expense ? abs(total) : total
    }

    private func bindingForCategory(_ category: Category) -> Binding<Double> {
        if let index = editingCategoryBudgets.firstIndex(where: { $0.categoryId == category.id }) {
            return $editingCategoryBudgets[index].plannedAmount
        } else {
            let newBudget = CategoryBudget(
                id: UUID().uuidString,
                categoryId: category.id,
                plannedAmount: 0,
                actualAmount: 0
            )
            editingCategoryBudgets.append(newBudget)
            return $editingCategoryBudgets[editingCategoryBudgets.count - 1].plannedAmount
        }
    }

    private func formatDateRange(_ range: DateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
    }
}

extension NumberFormatter {
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

struct CategoryRowAmount: View {
    let category: Category
    let plannedAmount: Double
    let actualAmount: Double
    let showingActual: Bool

    var body: some View {
        HStack {
            Text(category.name)
                .font(.headline)
            Spacer()
            Text(amountToShow(), format: .euro)
                .font(.subheadline)
                .foregroundColor(amountColor())
        }
    }

    private func amountToShow() -> Double {
        showingActual ? actualAmount : plannedAmount
    }

    private func amountColor() -> Color {
        let amount = amountToShow()
        if amount > 0 {
            return .green
        } else if amount < 0 {
            return .red
        } else {
            return .black
        }
    }
}

struct TotalCard: View {
    let title: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatAmount(amount))
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatAmount(_ amount: Double) -> String {
        amount.formatted(.euro)
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Si è verificato un errore")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: retryAction) {
                Text("Riprova")
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
