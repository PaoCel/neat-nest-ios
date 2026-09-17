import SwiftUI
import FirebaseDatabase

// MARK: - Transactions View
struct TransactionsView: View {
    @ObservedObject var budgetManager: BudgetManager
    @State private var selectedTab = 0
    @State private var showingAddTransaction = false

    private var allTransactions: [Transaction] {
        budgetManager.transactions.sorted { $0.date > $1.date }
    }

    private var incomeTransactions: [Transaction] {
        allTransactions.filter { $0.type == .income }
    }

    private var expenseTransactions: [Transaction] {
        allTransactions.filter { $0.type == .expense }
    }

    private var totalIncome: Double {
        incomeTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        expenseTransactions.reduce(0) { $0 + abs($1.amount) }
    }

    private var currentTransactions: [Transaction] {
        switch selectedTab {
        case 0: return allTransactions
        case 1: return incomeTransactions
        default: return expenseTransactions
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                TotalCard(title: "Totale Entrate", amount: totalIncome, color: .green)
                TotalCard(title: "Totale Uscite", amount: totalExpenses, color: .red)
            }
            .padding()

            Picker("Tipo", selection: $selectedTab) {
                Text("Tutte").tag(0)
                Text("Entrate").tag(1)
                Text("Uscite").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            List {
                ForEach(groupTransactionsByDate(currentTransactions)) { group in
                    TransactionSection(group: group, budgetManager: budgetManager)
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Transazioni")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTransaction = true }) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(budgetManager: budgetManager)
        }
    }

    private func groupTransactionsByDate(_ transactions: [Transaction]) -> [TransactionGroup] {
        let grouped = Dictionary(grouping: transactions) { $0.date }
        return grouped.map { TransactionGroup(date: $0.key, transactions: $0.value) }
            .sorted { $0.id > $1.id }
    }
}

// MARK: - Transaction Section View
struct TransactionSection: View {
    let group: TransactionGroup
    let budgetManager: BudgetManager

    var body: some View {
        Section(header: Text(formatDate(group.id))) {
            ForEach(group.transactions) { transaction in
                TransactionRow(
                    transaction: transaction,
                    category: budgetManager.categories.first { $0.id == transaction.categoryId }
                )
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let category: Category?

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category?.color ?? "#808080"))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                Text(category?.name ?? "Categoria sconosciuta")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(transaction.amount, format: .euro)
                .font(.headline)
                .foregroundColor(transaction.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    let budgetManager: BudgetManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transazioni Recenti")
                .font(.headline)
                .padding(.horizontal)

            if transactions.isEmpty {
                Text("Nessuna transazione")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(transactions.prefix(5))) { transaction in
                    TransactionRow(
                        transaction: transaction,
                        category: budgetManager.categories.first { $0.id == transaction.categoryId }
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}
