import SwiftUI
import FirebaseDatabase
import Combine

// MARK: - Category Management Row
struct CategoryManagementRow: View {
    let category: Category
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color(hex: category.color))
                    .frame(width: 32, height: 32)

                Text(category.name)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundColor(.primary)
        .opacity(category.isActive ? 1 : 0.5)
    }
}

// MARK: - Category Management View
struct CategoryManagementView: View {
    @ObservedObject var budgetManager: BudgetManager
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?

    private var incomeCategories: [Category] {
        budgetManager.categories
            .filter { $0.type == .income }
            .sorted { $0.name < $1.name }
    }

    private var expenseCategories: [Category] {
        budgetManager.categories
            .filter { $0.type == .expense }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section(header: Text("Categorie di Entrata")) {
                ForEach(incomeCategories) { category in
                    CategoryManagementRow(category: category) {
                        editingCategory = category
                    }
                }
            }

            Section(header: Text("Categorie di Uscita")) {
                ForEach(expenseCategories) { category in
                    CategoryManagementRow(category: category) {
                        editingCategory = category
                    }
                }
            }
        }
        .navigationTitle("Gestione Categorie")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryFormView(budgetManager: budgetManager, mode: .add)
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(budgetManager: budgetManager, mode: .edit(category))
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let plannedAmount: Double
    let actualAmount: Double
    let showingActual: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                if !showingActual {
                    Text("Previsto: \(formatAmount(plannedAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(formatAmount(showingActual ? actualAmount : plannedAmount))
                    .font(.headline)
                    .foregroundColor(Color(hex: category.color))

                if showingActual && plannedAmount > 0 {
                    let percentage = (actualAmount / plannedAmount) * 100
                    Text("\(String(format: "%.1f", percentage))% del previsto")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func formatAmount(_ amount: Double) -> String {
        amount.formatted(.euro)
    }
}

struct CategoryFormView: View {
    @ObservedObject var budgetManager: BudgetManager
    let mode: FormMode
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var type: Category.CategoryType = .expense
    @State private var selectedColor = "#1E90FF"

    enum FormMode {
        case add
        case edit(Category)

        var title: String {
            switch self {
            case .add: return "Nuova Categoria"
            case .edit: return "Modifica Categoria"
            }
        }
    }

    let colors = [
        "#1E90FF", "#32CD32", "#FF6347", "#FFD700",
        "#9370DB", "#20B2AA", "#FF69B4", "#F4A460",
        "#4682B4", "#8FBC8F", "#DDA0DD", "#F0E68C",
        "#CD5C5C", "#87CEEB", "#90EE90", "#FFA07A"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli")) {
                    TextField("Nome categoria", text: $name)

                    Picker("Tipo", selection: $type) {
                        Text("Entrata").tag(Category.CategoryType.income)
                        Text("Uscita").tag(Category.CategoryType.expense)
                    }
                }

                Section(header: Text("Colore")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarItems(
                leading: Button("Annulla") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salva") {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            )
            .onAppear {
                if case .edit(let category) = mode {
                    name = category.name
                    type = category.type
                    selectedColor = category.color
                }
            }
        }
    }

    private func saveCategory() {
        switch mode {
        case .add:
            let newCategory = Category(
                id: UUID().uuidString,
                name: name,
                type: type,
                color: selectedColor,
                familyId: budgetManager.userSession.familyId ?? "",
                isActive: true
            )
            budgetManager.addCategory(newCategory)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .store(in: &budgetManager.cancellables)

        case .edit(let category):
            let updatedCategory = Category(
                id: category.id,
                name: name,
                type: type,
                color: selectedColor,
                familyId: category.familyId,
                isActive: true
            )

            budgetManager.updateCategory(updatedCategory)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .store(in: &budgetManager.cancellables)
        }
    }
}

struct QuickAddCategoryView: View {
    @Binding var categoryName: String
    @Binding var categoryType: Category.CategoryType
    @Binding var categoryColor: String
    let onSave: () -> Void

    @Environment(\.presentationMode) var presentationMode

    private let predefinedColors = [
        "#1E90FF", "#32CD32", "#FF6347", "#FFD700",
        "#9370DB", "#20B2AA", "#FF69B4", "#F4A460"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Categoria")) {
                    TextField("Nome categoria", text: $categoryName)

                    Picker("Tipo", selection: $categoryType) {
                        Text("Uscita").tag(Category.CategoryType.expense)
                        Text("Entrata").tag(Category.CategoryType.income)
                    }
                }

                Section(header: Text("Colore")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: categoryColor == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    categoryColor = color
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Nuova Categoria")
            .navigationBarItems(
                leading: Button("Annulla") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salva") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(categoryName.isEmpty)
            )
        }
    }
}

struct EditingCategoryRow: View {
    let category: Category
    @Binding var amount: Double

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 24, height: 24)

            Text(category.name)

            Spacer()

            HStack {
                // `TextField(value:format:)` legge e scrive nel formato del
                // locale: l'italiano digita la virgola, l'inglese il punto.
                TextField("0,00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)

                Text(verbatim: "€")
            }
        }
    }
}
