import Foundation
import FirebaseFirestore
import Combine

// MARK: - Budget Manager
class BudgetManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var currentMonth: BudgetMonth?
    @Published var budgetMonths: [BudgetMonth] = []
    @Published var monthTransactions: [Transaction] = []

    var cancellables = Set<AnyCancellable>()
    let userSession: UserSession

    private let firestore = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var observedMonthForTransactions: BudgetMonth?

    init(userSession: UserSession) {
        self.userSession = userSession
        setupObservers()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Transaction Methods
    func addTransaction(_ transaction: Transaction) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            let transactionRef = self.firestore.collection("transactions").document(transaction.id)
            transactionRef.setData(self.transactionData(from: transaction, familyId: familyId)) { error in
                if let error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func observeTransactionsForMonth(_ month: BudgetMonth) {
        observedMonthForTransactions = month
        applyObservedMonthFilter()
    }

    func loadAllTransactions() {
        applyObservedMonthFilter()
    }

    // MARK: - Category Methods
    func addCategory(_ category: Category) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            let categoryRef = self.firestore.collection("categories").document(category.id)
            categoryRef.setData(self.categoryData(from: category, familyId: familyId)) { error in
                if let error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func loadCategories() {
        guard let familyId = userSession.familyId else { return }

        firestore.collection("categories")
            .whereField("familyId", isEqualTo: familyId)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                guard error == nil else { return }

                let loadedCategories = snapshot?.documents.compactMap { document in
                    self.parseCategory(id: document.documentID, data: document.data())
                } ?? []

                DispatchQueue.main.async {
                    self.categories = loadedCategories.sorted { $0.name < $1.name }
                }
            }
    }

    // MARK: - Budget Month Methods
    func createBudgetMonth(_ budgetMonth: BudgetMonth) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            let budgetRef = self.firestore.collection("budgetMonths").document(budgetMonth.id)
            budgetRef.setData(self.budgetMonthData(from: budgetMonth, familyId: familyId, includeCreatedAt: true)) { error in
                if let error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func setupObservers() {
        guard let familyId = userSession.familyId else { return }

        removeListeners()

        let transactionsListener = firestore.collection("transactions")
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard error == nil else {
                    print("Errore nel caricamento delle transazioni: \(error!.localizedDescription)")
                    return
                }

                let loadedTransactions = snapshot?.documents.compactMap { document in
                    self.parseTransaction(id: document.documentID, data: document.data())
                } ?? []

                DispatchQueue.main.async {
                    self.transactions = loadedTransactions.sorted { $0.date > $1.date }
                    self.applyObservedMonthFilter()
                }

                self.synchronizeBudgetMonthsIfNeeded(
                    transactions: loadedTransactions,
                    budgetMonths: self.budgetMonths,
                    familyId: familyId
                )
            }

        let categoriesListener = firestore.collection("categories")
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard error == nil else {
                    print("Errore nel caricamento delle categorie: \(error!.localizedDescription)")
                    return
                }

                let loadedCategories = snapshot?.documents.compactMap { document in
                    self.parseCategory(id: document.documentID, data: document.data())
                } ?? []

                DispatchQueue.main.async {
                    self.categories = loadedCategories.sorted { $0.name < $1.name }
                }
            }

        let budgetMonthsListener = firestore.collection("budgetMonths")
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard error == nil else {
                    print("Errore nel caricamento dei budget mensili: \(error!.localizedDescription)")
                    return
                }

                let months = snapshot?.documents.compactMap { document in
                    self.parseBudgetMonth(id: document.documentID, data: document.data())
                }
                .sorted { $0.dateRange.startDate > $1.dateRange.startDate } ?? []

                DispatchQueue.main.async {
                    self.budgetMonths = months
                    let now = Date()
                    self.currentMonth = months.first { $0.dateRange.contains(now) }
                    self.applyObservedMonthFilter()
                }

                self.synchronizeBudgetMonthsIfNeeded(
                    transactions: self.transactions,
                    budgetMonths: months,
                    familyId: familyId
                )
            }

        listeners = [transactionsListener, categoriesListener, budgetMonthsListener]
    }

    func transactions(for budgetMonth: BudgetMonth) -> [Transaction] {
        transactions.filter { budgetMonth.dateRange.contains($0.date) }
    }

    func actualIncome(for budgetMonth: BudgetMonth) -> Double {
        transactions(for: budgetMonth)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    func actualExpenses(for budgetMonth: BudgetMonth) -> Double {
        transactions(for: budgetMonth)
            .filter { $0.type == .expense }
            .reduce(0) { $0 + abs($1.amount) }
    }

    func actualBalance(for budgetMonth: BudgetMonth) -> Double {
        actualIncome(for: budgetMonth) - actualExpenses(for: budgetMonth)
    }

    func actualAmount(for category: Category, in budgetMonth: BudgetMonth) -> Double {
        let total = transactions(for: budgetMonth)
            .filter { $0.categoryId == category.id }
            .reduce(0) { $0 + $1.amount }

        return category.type == .expense ? abs(total) : total
    }

    // MARK: - Error Handling
    enum BudgetError: Error {
        case noFamilyId
        case invalidData
        case networkError
    }
}

// MARK: - Firebase Parsing Functions
extension BudgetManager {
    func parseTransaction(id: String, data: [String: Any]) -> Transaction? {
        Transaction.fromDictionary(data, id: id)
    }

    func parseCategory(id: String, data: [String: Any]) -> Category? {
        guard let name = data["name"] as? String,
              let typeString = data["type"] as? String,
              let type = Category.CategoryType(rawValue: typeString),
              let color = data["color"] as? String,
              let familyId = data["familyId"] as? String else {
            return nil
        }

        let isActive = data["isActive"] as? Bool ?? true

        return Category(
            id: id,
            name: name,
            type: type,
            color: color,
            familyId: familyId,
            isActive: isActive
        )
    }

    func parseBudgetMonth(id: String, data: [String: Any]) -> BudgetMonth? {
        guard let name = data["name"] as? String,
              let dateRangeData = data["dateRange"] as? [String: Any],
              let totalPlannedIncome = doubleValue(from: data["totalPlannedIncome"]),
              let totalPlannedExpenses = doubleValue(from: data["totalPlannedExpenses"]),
              let familyId = data["familyId"] as? String else {
            return nil
        }

        guard let startDateString = dateRangeData["startDate"] as? String,
              let endDateString = dateRangeData["endDate"] as? String else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let startDate = formatter.date(from: startDateString),
              let endDate = formatter.date(from: endDateString) else {
            return nil
        }

        let dateRange = DateRange(startDate: startDate, endDate: endDate)
        let budgetsPayload = data["categoryBudgets"] as? [Any] ?? []
        let categoryBudgets = budgetsPayload.compactMap { item -> CategoryBudget? in
            guard let budgetData = item as? [String: Any],
                  let categoryId = budgetData["categoryId"] as? String,
                  let plannedAmount = doubleValue(from: budgetData["plannedAmount"]),
                  let actualAmount = doubleValue(from: budgetData["actualAmount"]) else {
                return nil
            }

            return CategoryBudget(
                id: budgetData["id"] as? String ?? UUID().uuidString,
                categoryId: categoryId,
                plannedAmount: plannedAmount,
                actualAmount: actualAmount
            )
        }

        return BudgetMonth(
            id: id,
            name: name,
            dateRange: dateRange,
            categoryBudgets: categoryBudgets,
            totalPlannedIncome: totalPlannedIncome,
            totalPlannedExpenses: totalPlannedExpenses,
            totalActualIncome: doubleValue(from: data["totalActualIncome"]) ?? 0,
            totalActualExpenses: doubleValue(from: data["totalActualExpenses"]) ?? 0,
            familyId: familyId
        )
    }
}

extension BudgetManager {
    func updateCategory(_ category: Category) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            let categoryRef = self.firestore.collection("categories").document(category.id)
            categoryRef.setData(self.categoryData(from: category, familyId: familyId), merge: true) { error in
                if let error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - Budget Manager Firebase Integration
extension BudgetManager {
    func loadBudgetMonth(id: String) -> AnyPublisher<BudgetMonth?, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success(nil))
                return
            }

            self.firestore.collection("budgetMonths").document(id).getDocument { snapshot, error in
                if let error {
                    promise(.failure(error))
                    return
                }

                guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                    promise(.success(nil))
                    return
                }

                promise(.success(self.parseBudgetMonth(id: snapshot.documentID, data: data)))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateBudgetMonth(_ budgetMonth: BudgetMonth) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            self.firestore.collection("budgetMonths").document(budgetMonth.id)
                .setData(self.budgetMonthData(from: budgetMonth, familyId: familyId, includeCreatedAt: false), merge: true) { error in
                    if let error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
        }
        .eraseToAnyPublisher()
    }

    func updateActualAmounts(for budgetMonth: BudgetMonth) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self,
                  let familyId = self.userSession.familyId else {
                promise(.failure(BudgetError.noFamilyId))
                return
            }

            let synchronizedMonth = self.synchronizedBudgetMonth(budgetMonth, using: self.transactions)

            self.firestore.collection("budgetMonths").document(budgetMonth.id)
                .updateData(self.actualAmountsUpdateData(from: synchronizedMonth, familyId: familyId)) { error in
                    if let error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Private Helpers
private extension BudgetManager {
    func removeListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func applyObservedMonthFilter() {
        guard let observedMonthForTransactions else {
            monthTransactions = []
            return
        }

        monthTransactions = transactions.filter { observedMonthForTransactions.dateRange.contains($0.date) }
    }

    func categoryData(from category: Category, familyId: String) -> [String: Any] {
        [
            "name": category.name,
            "type": category.type.rawValue,
            "color": category.color,
            "familyId": familyId,
            "isActive": category.isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func transactionData(from transaction: Transaction, familyId: String) -> [String: Any] {
        [
            "type": transaction.type.rawValue,
            "date": Timestamp(date: transaction.date),
            "categoryId": transaction.categoryId,
            "paymentMethod": transaction.paymentMethod,
            "createdBy": transaction.createdBy,
            "description": transaction.description,
            "amount": transaction.amount,
            "familyId": familyId,
            "monthYearId": monthYearIdentifier(for: transaction.date),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func budgetMonthData(from budgetMonth: BudgetMonth, familyId: String, includeCreatedAt: Bool) -> [String: Any] {
        var data: [String: Any] = [
            "name": budgetMonth.name,
            "dateRange": budgetMonth.dateRange.dictionary,
            "categoryBudgets": budgetMonth.categoryBudgets.map { $0.dictionary },
            "totalPlannedIncome": budgetMonth.totalPlannedIncome,
            "totalPlannedExpenses": budgetMonth.totalPlannedExpenses,
            "totalActualIncome": budgetMonth.totalActualIncome,
            "totalActualExpenses": budgetMonth.totalActualExpenses,
            "familyId": familyId,
            "monthYearId": monthYearIdentifier(for: budgetMonth.dateRange.startDate),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if includeCreatedAt {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        return data
    }

    func actualAmountsUpdateData(from budgetMonth: BudgetMonth, familyId: String) -> [String: Any] {
        [
            "totalActualIncome": budgetMonth.totalActualIncome,
            "totalActualExpenses": budgetMonth.totalActualExpenses,
            "categoryBudgets": budgetMonth.categoryBudgets.map { $0.dictionary },
            "familyId": familyId,
            "monthYearId": monthYearIdentifier(for: budgetMonth.dateRange.startDate),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func monthYearIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    func doubleValue(from value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }

        if let int = value as? Int {
            return Double(int)
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        return nil
    }

    func synchronizedBudgetMonth(_ budgetMonth: BudgetMonth, using transactions: [Transaction]) -> BudgetMonth {
        let relevantTransactions = transactions.filter { budgetMonth.dateRange.contains($0.date) }
        let actualIncome = relevantTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }

        let actualExpenses = relevantTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + abs($1.amount) }

        var updatedCategoryBudgets = budgetMonth.categoryBudgets
        for index in updatedCategoryBudgets.indices {
            let categoryId = updatedCategoryBudgets[index].categoryId
            let categoryTransactions = relevantTransactions.filter { $0.categoryId == categoryId }
            let total = categoryTransactions.reduce(0) { $0 + $1.amount }
            let categoryType = categories.first(where: { $0.id == categoryId })?.type
            updatedCategoryBudgets[index].actualAmount = categoryType == .expense ? abs(total) : total
        }

        return BudgetMonth(
            id: budgetMonth.id,
            name: budgetMonth.name,
            dateRange: budgetMonth.dateRange,
            categoryBudgets: updatedCategoryBudgets,
            totalPlannedIncome: budgetMonth.totalPlannedIncome,
            totalPlannedExpenses: budgetMonth.totalPlannedExpenses,
            totalActualIncome: actualIncome,
            totalActualExpenses: actualExpenses,
            familyId: budgetMonth.familyId
        )
    }

    func synchronizeBudgetMonthsIfNeeded(transactions: [Transaction], budgetMonths: [BudgetMonth], familyId: String) {
        guard !budgetMonths.isEmpty else { return }

        for month in budgetMonths {
            let synchronizedMonth = synchronizedBudgetMonth(month, using: transactions)
            guard monthNeedsSynchronization(original: month, synchronized: synchronizedMonth) else {
                continue
            }

            firestore.collection("budgetMonths")
                .document(month.id)
                .updateData(actualAmountsUpdateData(from: synchronizedMonth, familyId: familyId))
        }
    }

    func monthNeedsSynchronization(original: BudgetMonth, synchronized: BudgetMonth) -> Bool {
        guard abs(original.totalActualIncome - synchronized.totalActualIncome) > 0.009 ||
              abs(original.totalActualExpenses - synchronized.totalActualExpenses) > 0.009 else {
            let originalBudgets = Dictionary(uniqueKeysWithValues: original.categoryBudgets.map { ($0.categoryId, $0.actualAmount) })
            let synchronizedBudgets = Dictionary(uniqueKeysWithValues: synchronized.categoryBudgets.map { ($0.categoryId, $0.actualAmount) })

            for (categoryId, actualAmount) in synchronizedBudgets {
                let originalAmount = originalBudgets[categoryId] ?? 0
                if abs(originalAmount - actualAmount) > 0.009 {
                    return true
                }
            }

            return false
        }

        return true
    }
}
