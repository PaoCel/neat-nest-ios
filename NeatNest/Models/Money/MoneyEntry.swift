import Foundation
import FirebaseFirestore

/// Un movimento di denaro: entra o esce.
///
/// Volutamente povero. Niente categorie, niente budget mensili, niente
/// previsto/effettivo: quella complessità c'è già nel modulo Budget e non è
/// servita a nessuno. Qui contano tre cose — quanto, quando, dentro o fuori.
struct MoneyEntry: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Hashable, Sendable {
        case income
        case expense

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .income:
                return "Entrata"
            case .expense:
                return "Uscita"
            }
        }

        var icon: String {
            switch self {
            case .income:
                return "arrow.down.circle.fill"
            case .expense:
                return "arrow.up.circle.fill"
            }
        }

        /// Il segno con cui il movimento entra nel saldo.
        var sign: Double {
            self == .income ? 1 : -1
        }
    }

    /// Da dove arriva il movimento: serve a spiegare all'utente perché una riga
    /// è comparsa da sola.
    enum Source: String, CaseIterable, Identifiable, Hashable, Sendable {
        case manual
        case receipt

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .manual:
                return "Inserita a mano"
            case .receipt:
                return "Da scontrino"
            }
        }
    }

    let id: String
    let userId: String
    var kind: Kind
    var amount: Double
    var note: String
    var date: Date
    var source: Source
    /// Lo scontrino da cui nasce, per poter risalire alla spesa originale.
    var receiptImportId: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        kind: Kind,
        amount: Double,
        note: String,
        date: Date = Date(),
        source: Source = .manual,
        receiptImportId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.amount = abs(amount)
        self.note = note
        self.date = date
        self.source = source
        self.receiptImportId = receiptImportId
        self.createdAt = createdAt
    }

    /// Importo con segno, pronto da sommare.
    var signedAmount: Double {
        amount * kind.sign
    }
}

// MARK: - Firestore

extension MoneyEntry {
    static func fromDocument(id: String, data: [String: Any]) -> MoneyEntry? {
        guard let userId = data["userId"] as? String,
              let kind = Kind(rawValue: data["kind"] as? String ?? "") else {
            return nil
        }

        let amount = groceryDoubleValue(from: data["amount"])
        guard amount > 0 else { return nil }

        let date = groceryDateValue(from: data["date"]) ?? Date()

        return MoneyEntry(
            id: id,
            userId: userId,
            kind: kind,
            amount: amount,
            note: data["note"] as? String ?? "",
            date: date,
            source: Source(rawValue: data["source"] as? String ?? "") ?? .manual,
            receiptImportId: data["receiptImportId"] as? String,
            createdAt: groceryDateValue(from: data["createdAt"]) ?? date
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "kind": kind.rawValue,
            "amount": amount,
            "note": note,
            "date": Timestamp(date: date),
            "source": source.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let receiptImportId { data["receiptImportId"] = receiptImportId }

        return data
    }
}

/// Saldo di un periodo: entrate, uscite, differenza.
struct MoneyBalance: Hashable, Sendable {
    let income: Double
    let expenses: Double

    var delta: Double { income - expenses }
    var isPositive: Bool { delta >= 0 }

    static let zero = MoneyBalance(income: 0, expenses: 0)

    init(income: Double, expenses: Double) {
        self.income = income
        self.expenses = expenses
    }

    init(entries: [MoneyEntry]) {
        income = entries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        expenses = entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    }
}
