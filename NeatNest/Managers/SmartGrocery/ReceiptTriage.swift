import Foundation

/// Che tipo di scontrino è, guardando cosa contiene.
enum ReceiptKind: String, Hashable, Sendable {
    /// Solo roba da mangiare: va tutta in dispensa.
    case grocery
    /// Spesa mista: alimentari più detersivi, pile, calze.
    case mixed
    /// Niente di alimentare: farmacia, ferramenta, benzina.
    case nonGrocery

    var title: LocalizedStringResource {
        switch self {
        case .grocery:
            return "Spesa alimentare"
        case .mixed:
            return "Spesa mista"
        case .nonGrocery:
            return "Altra spesa"
        }
    }

    var icon: String {
        switch self {
        case .grocery:
            return "carrot"
        case .mixed:
            return "cart"
        case .nonGrocery:
            return "bag"
        }
    }
}

/// Uno scontrino diviso in ciò che va in dispensa e ciò che è solo una spesa.
struct ReceiptTriage: Sendable {
    let parsed: ParsedReceipt
    let foodLines: [ParsedReceiptLine]
    let otherLines: [ParsedReceiptLine]

    var kind: ReceiptKind {
        if foodLines.isEmpty { return .nonGrocery }
        if otherLines.isEmpty { return .grocery }
        return .mixed
    }

    var foodTotal: Double {
        foodLines.reduce(0) { $0 + $1.lineTotal }
    }

    var otherTotal: Double {
        otherLines.reduce(0) { $0 + $1.lineTotal }
    }

    /// Quanto è stato speso: il totale stampato se c'è, altrimenti la somma
    /// delle righe lette.
    var total: Double {
        parsed.declaredTotal ?? parsed.computedTotal
    }

    var retailerName: String {
        parsed.retailerName ?? String(
            localized: "receipt.scan.unknownRetailer",
            defaultValue: "Negozio non riconosciuto"
        )
    }

    var purchaseDate: Date {
        parsed.purchaseDate ?? Date()
    }

    var hasFood: Bool { !foodLines.isEmpty }
}

/// Decide, riga per riga, cosa è cibo e cosa no.
///
/// Serve perché lo scontrino non è solo la spesa: è anche il detersivo, le pile
/// e la benzina. Tutto è una spesa da registrare, ma solo il cibo entra in
/// dispensa.
struct ReceiptTriageService: Sendable {
    private let categoryInferrer: ReceiptCategoryInferrer
    private let locale: Locale

    init(
        categoryInferrer: ReceiptCategoryInferrer = ReceiptCategoryInferrer(),
        locale: Locale = .autoupdatingCurrent
    ) {
        self.categoryInferrer = categoryInferrer
        self.locale = locale
    }

    func triage(_ parsed: ParsedReceipt) -> ReceiptTriage {
        var food: [ParsedReceiptLine] = []
        var other: [ParsedReceiptLine] = []

        for line in parsed.lines {
            if isFood(line) {
                food.append(line)
            } else {
                other.append(line)
            }
        }

        return ReceiptTriage(parsed: parsed, foodLines: food, otherLines: other)
    }

    /// Due segnali che devono essere d'accordo: la categoria di spesa dedotta e
    /// il profilo di conservazione. Se il nome dice "detersivo", non importa in
    /// quale categoria sia finito.
    func isFood(_ line: ParsedReceiptLine) -> Bool {
        let category = categoryInferrer.inferCategory(rawLineText: line.rawText, matchedProduct: nil).category

        switch category {
        case .household, .leisure:
            return false
        default:
            break
        }

        let profile = ShelfLifeCatalog.profile(
            forProductNamed: line.rawText,
            category: category,
            locale: locale
        )

        return profile != .nonFood
    }
}
