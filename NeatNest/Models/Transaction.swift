import Foundation
import FirebaseFirestore

struct Transaction: Identifiable {
    let id: String
    let type: TransactionType
    let date: Date
    let categoryId: String
    let paymentMethod: String
    let createdBy: String
    let description: String
    let amount: Double
    let familyId: String

    enum TransactionType: String {
        case income = "income"
        case expense = "expense"
    }

    static func fromDictionary(_ dict: [String: Any], id: String) -> Transaction? {
        guard
            let typeString = dict["type"] as? String,
            let type = TransactionType(rawValue: typeString),
            let categoryId = dict["categoryId"] as? String,
            let paymentMethod = dict["paymentMethod"] as? String,
            let createdBy = dict["createdBy"] as? String,
            let description = dict["description"] as? String,
            let amount = dict["amount"] as? Double,
            let familyId = dict["familyId"] as? String
        else {
            return nil
        }

        var date: Date?
        if let timestamp = dict["date"] as? Timestamp {
            date = timestamp.dateValue()
        } else if let dateInterval = dict["date"] as? TimeInterval {
            date = Date(timeIntervalSince1970: dateInterval)
        } else if let dateNumber = dict["date"] as? NSNumber {
            date = Date(timeIntervalSince1970: dateNumber.doubleValue)
        } else if let dateString = dict["date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: dateString)
        }

        guard let transactionDate = date else {
            return nil
        }

        return Transaction(
            id: id,
            type: type,
            date: transactionDate,
            categoryId: categoryId,
            paymentMethod: paymentMethod,
            createdBy: createdBy,
            description: description,
            amount: amount,
            familyId: familyId
        )
    }
}

struct TransactionGroup: Identifiable {
    let id: Date
    let transactions: [Transaction]

    init(date: Date, transactions: [Transaction]) {
        self.id = date
        self.transactions = transactions
    }
}
