import SwiftUI
import FirebaseDatabase

// MARK: - Budget Home View
struct BudgetHomeView: View {
    @State private var viewModel: BudgetHomeViewModel

    init(userSession: UserSession) {
        _viewModel = State(initialValue: BudgetHomeViewModel(userSession: userSession))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        NavigationLink(destination: TransactionsView(budgetManager: viewModel.budgetManager)) {
                            TopNavButton(
                                title: "Transazioni",
                                icon: "list.bullet",
                                color: .blue
                            )
                        }

                        NavigationLink(destination: BudgetListView(budgetManager: viewModel.budgetManager)) {
                            TopNavButton(
                                title: "Dettagli Budget",
                                icon: "chart.pie.fill",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)

                    if !viewModel.budgetManager.budgetMonths.isEmpty {
                        if let currentMonth = viewModel.currentMonth {
                            CurrentMonthSummaryView(budgetMonth: currentMonth, budgetManager: viewModel.budgetManager)
                                .padding(.horizontal)
                        } else {
                            Text("Nessuna mensilità corrente trovata")
                                .padding(.horizontal)
                        }
                    } else {
                        NoDataView()
                            .padding(.horizontal)
                    }

                    if let depositBalance = viewModel.depositBalance {
                        DepositBalanceView(balance: depositBalance)
                            .padding(.horizontal)
                    }

                    if !viewModel.recentTransactions.isEmpty {
                        RecentTransactionsSection(
                            transactions: viewModel.recentTransactions,
                            budgetManager: viewModel.budgetManager
                        )
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .navigationTitle("Budget")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CategoryManagementView(budgetManager: viewModel.budgetManager)) {
                            Image(systemName: "folder.badge.plus")
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
    }
}

struct TopNavButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(10)
    }
}

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("Nessuna mensilità creata")
                .font(.headline)

            Text("Crea il tuo primo budget mensile per iniziare a tracciare le tue finanze")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct DepositBalanceView: View {
    let balance: Double

    var body: some View {
        VStack {
            Text("Saldo Deposito")
                .font(.headline)
            Text(balance, format: .euro)
                .font(.title)
                .foregroundColor(balance >= 0 ? .green : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
