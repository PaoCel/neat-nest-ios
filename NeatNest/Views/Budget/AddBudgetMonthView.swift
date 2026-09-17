import SwiftUI
import FirebaseDatabase
import Combine

struct AddBudgetMonthView: View {
    @ObservedObject var budgetManager: BudgetManager
    @Environment(\.presentationMode) var presentationMode

    var editingBudget: BudgetMonth?

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var categoryBudgets: [CategoryBudget] = []
    @State private var showingAddCategory = false

    private var isEditing: Bool {
        editingBudget != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Mese")) {
                    TextField("Nome mese", text: $name)
                    DatePicker("Data inizio", selection: $startDate, displayedComponents: .date)
                    DatePicker("Data fine", selection: $endDate, displayedComponents: .date)
                }

                Section(header: HeaderWithAddButton("Categorie di Entrata", action: {
                    showingAddCategory = true
                })) {
                    ForEach(budgetManager.categories.filter { $0.type == .income }) { category in
                        CategoryBudgetRow(
                            category: category,
                            amount: binding(for: category)
                        )
                    }
                }

                Section(header: HeaderWithAddButton("Categorie di Uscita", action: {
                    showingAddCategory = true
                })) {
                    ForEach(budgetManager.categories.filter { $0.type == .expense }) { category in
                        CategoryBudgetRow(
                            category: category,
                            amount: binding(for: category)
                        )
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Budget" : "Nuovo Budget")
            .navigationBarItems(
                leading: Button("Annulla") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salva") {
                    saveBudget()
                }
                    .disabled(!isValid)
            )
            .sheet(isPresented: $showingAddCategory) {
                QuickAddCategoryView(
                    categoryName: .constant(""),
                    categoryType: .constant(.expense),
                    categoryColor: .constant("#1E90FF")
                ) {
                    // Handle category save
                }
            }
            .onAppear {
                if let budget = editingBudget {
                    name = budget.name
                    startDate = budget.dateRange.startDate
                    endDate = budget.dateRange.endDate
                    categoryBudgets = budget.categoryBudgets
                } else {
                    categoryBudgets = budgetManager.categories.map { category in
                        CategoryBudget(
                            id: UUID().uuidString,
                            categoryId: category.id,
                            plannedAmount: 0,
                            actualAmount: 0
                        )
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && endDate > startDate
    }

    private func binding(for category: Category) -> Binding<Double> {
        if let index = categoryBudgets.firstIndex(where: { $0.categoryId == category.id }) {
            return Binding(
                get: { categoryBudgets[index].plannedAmount },
                set: { categoryBudgets[index].plannedAmount = $0 }
            )
        } else {
            return .constant(0)
        }
    }

    private func saveBudget() {
        let budgetMonth = BudgetMonth(
            id: editingBudget?.id ?? UUID().uuidString,
            name: name,
            dateRange: DateRange(startDate: startDate, endDate: endDate),
            categoryBudgets: categoryBudgets,
            totalPlannedIncome: plannedTotal(for: .income),
            totalPlannedExpenses: plannedTotal(for: .expense),
            totalActualIncome: editingBudget?.totalActualIncome ?? 0,
            totalActualExpenses: editingBudget?.totalActualExpenses ?? 0,
            familyId: budgetManager.userSession.familyId ?? ""
        )

        if isEditing {
            budgetManager.updateBudgetMonth(budgetMonth)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .store(in: &budgetManager.cancellables)
        } else {
            budgetManager.createBudgetMonth(budgetMonth)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .store(in: &budgetManager.cancellables)
        }
    }

    private func plannedTotal(for type: Category.CategoryType) -> Double {
        categoryBudgets.reduce(0) { partialResult, categoryBudget in
            guard let category = budgetManager.categories.first(where: { $0.id == categoryBudget.categoryId }),
                  category.type == type else {
                return partialResult
            }

            return partialResult + categoryBudget.plannedAmount
        }
    }
}

// MARK: - Supporting Views
struct HeaderWithAddButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: action) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct CategoryBudgetRow: View {
    let category: Category
    @Binding var amount: Double


    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 24, height: 24)

            Text(category.name)

            Spacer()

            TextField("0,00", value: $amount, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
