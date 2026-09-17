import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var budgetManager: BudgetManager
    @Environment(\.presentationMode) var presentationMode

    @State private var date = Date()
    @State private var type: Transaction.TransactionType = .expense
    @State private var description = ""
    @State private var selectedCategory: Category?
    @State private var amount = ""
    @State private var paymentMethod = ""
    @State private var showingAddCategory = false

    @State private var newCategoryName = ""
    @State private var newCategoryType: Category.CategoryType = .expense
    @State private var newCategoryColor = "#1E90FF"

    private var filteredCategories: [Category] {
        budgetManager.categories.filter { $0.type.rawValue == type.rawValue }
    }

    var body: some View {
        NavigationView {
            Form {
                detailsSection
                categorySection
                paymentSection
            }
            .navigationTitle("Nuova Transazione")
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .sheet(isPresented: $showingAddCategory) {
                QuickAddCategoryView(
                    categoryName: $newCategoryName,
                    categoryType: $newCategoryType,
                    categoryColor: $newCategoryColor,
                    onSave: saveCategory
                )
            }
        }
    }

    private var detailsSection: some View {
        Section(header: Text("Dettagli")) {
            DatePicker("Data", selection: $date, displayedComponents: .date)

            Picker("Tipo", selection: $type) {
                Text("Uscita").tag(Transaction.TransactionType.expense)
                Text("Entrata").tag(Transaction.TransactionType.income)
            }

            TextField("Descrizione", text: $description)
        }
    }

    private var categorySection: some View {
        Section(header: Text("Categoria")) {
            if filteredCategories.isEmpty {
                Text("Nessuna categoria disponibile")
                    .foregroundColor(.secondary)
            } else {
                Picker("Categoria", selection: $selectedCategory) {
                    ForEach(filteredCategories) { category in
                        CategoryPickerRow(category: category)
                            .tag(Optional(category))
                    }
                }
            }

            addCategoryButton
        }
    }

    private var paymentSection: some View {
        Section(header: Text("Importo e Pagamento")) {
            TextField("Importo", text: $amount)
                .keyboardType(.decimalPad)

            TextField("Metodo di pagamento", text: $paymentMethod)
        }
    }

    private var cancelButton: some View {
        Button("Annulla") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var saveButton: some View {
        Button("Salva") {
            saveTransaction()
        }
        .disabled(!isValid)
    }

    private var addCategoryButton: some View {
        Button(action: { showingAddCategory = true }) {
            Label("Aggiungi categoria", systemImage: "plus.circle")
        }
    }

    struct CategoryPickerRow: View, Hashable {
        let category: Category

        static func == (lhs: CategoryPickerRow, rhs: CategoryPickerRow) -> Bool {
            lhs.category.id == rhs.category.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(category.id)
        }

        var body: some View {
            HStack {
                Circle()
                    .fill(Color(hex: category.color))
                    .frame(width: 12, height: 12)
                Text(category.name)
            }
        }
    }

    private var isValid: Bool {
        !description.isEmpty &&
        !amount.isEmpty &&
        selectedCategory != nil &&
        !paymentMethod.isEmpty &&
        Double(amount) != nil
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount),
              let category = selectedCategory else { return }

        let transaction = Transaction(
            id: UUID().uuidString,
            type: type,
            date: date,
            categoryId: category.id,
            paymentMethod: paymentMethod,
            createdBy: budgetManager.userSession.currentUserName,
            description: description,
            amount: type == .expense ? -abs(amountValue) : abs(amountValue),
            familyId: budgetManager.userSession.familyId ?? ""
        )

        budgetManager.addTransaction(transaction)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error saving transaction: \(error)")
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &budgetManager.cancellables)
    }

    private func saveCategory() {
        let category = Category(
            id: UUID().uuidString,
            name: newCategoryName,
            type: newCategoryType,
            color: newCategoryColor,
            familyId: budgetManager.userSession.familyId ?? "",
            isActive: true
        )

        budgetManager.addCategory(category)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: {
                    selectedCategory = category
                    showingAddCategory = false
                }
            )
            .store(in: &budgetManager.cancellables)
    }
}
