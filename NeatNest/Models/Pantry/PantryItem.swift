import Foundation
import FirebaseFirestore
import SwiftUI

/// Dove il prodotto è conservato: determina la shelf life e come raggruppare la lista.
enum PantryStorage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case fridge
    case freezer
    case pantry
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .fridge:
            return "Frigo"
        case .freezer:
            return "Congelatore"
        case .pantry:
            return "Dispensa"
        case .other:
            return "Altro"
        }
    }

    var icon: String {
        switch self {
        case .fridge:
            return "refrigerator"
        case .freezer:
            return "snowflake"
        case .pantry:
            return "cabinet"
        case .other:
            return "shippingbox"
        }
    }

    /// Il congelatore moltiplica la durata; la dispensa la allunga rispetto al frigo.
    var shelfLifeMultiplier: Double {
        switch self {
        case .fridge:
            return 1
        case .freezer:
            return 8
        case .pantry:
            return 1
        case .other:
            return 1
        }
    }

    static func suggested(for category: GrocerySpendingCategory) -> PantryStorage {
        switch category {
        case .produce, .dairy, .protein:
            return .fridge
        case .pantry, .bakery, .beverages:
            return .pantry
        case .household, .leisure, .other:
            return .other
        }
    }
}

/// Come il prodotto è finito in dispensa. Serve a spiegare all'utente da dove
/// arriva una riga che non ha inserito a mano, e a rendere annullabile un import.
enum PantrySource: String, CaseIterable, Identifiable, Hashable, Sendable {
    case manual
    case receipt
    case groceryList
    case recipe

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .manual:
            return "Aggiunto a mano"
        case .receipt:
            return "Da scontrino"
        case .groceryList:
            return "Da lista spesa"
        case .recipe:
            return "Da ricetta"
        }
    }

    var icon: String {
        switch self {
        case .manual:
            return "hand.point.up.left"
        case .receipt:
            return "doc.text.viewfinder"
        case .groceryList:
            return "cart"
        case .recipe:
            return "fork.knife"
        }
    }
}

/// Stato di freschezza calcolato, non memorizzato: dipende da "adesso".
enum PantryFreshness: Hashable, Sendable {
    case expired
    case expiringSoon(daysLeft: Int)
    case fresh(daysLeft: Int)
    case unknown

    var sortRank: Int {
        switch self {
        case .expired:
            return 0
        case .expiringSoon:
            return 1
        case .fresh:
            return 2
        case .unknown:
            return 3
        }
    }

    var tint: Color {
        switch self {
        case .expired:
            return .red
        case .expiringSoon:
            return .orange
        case .fresh:
            return .green
        case .unknown:
            return .secondary
        }
    }

    var icon: String {
        switch self {
        case .expired:
            return "exclamationmark.triangle.fill"
        case .expiringSoon:
            return "clock.badge.exclamationmark"
        case .fresh:
            return "checkmark.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var isActionable: Bool {
        switch self {
        case .expired, .expiringSoon:
            return true
        case .fresh, .unknown:
            return false
        }
    }
}

/// Quanto ne resta, espresso come lo direbbe una persona.
///
/// Nessuno pesa la ricotta avanzata. La quantità esatta di un prodotto aperto
/// non è un dato che si possa chiedere: si chiede uno stato, con un tap.
enum PantryLevel: String, CaseIterable, Identifiable, Hashable, Sendable {
    case sealed
    case plenty
    case half
    case low
    case finished

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .sealed:
            return "Chiuso"
        case .plenty:
            return "Quasi pieno"
        case .half:
            return "Metà"
        case .low:
            return "Poco"
        case .finished:
            return "Finito"
        }
    }

    var icon: String {
        switch self {
        case .sealed:
            return "shippingbox.fill"
        case .plenty:
            return "cylinder.split.1x2.fill"
        case .half:
            return "circle.lefthalf.filled"
        case .low:
            return "circle.bottomhalf.filled"
        case .finished:
            return "circle"
        }
    }

    /// Frazione stimata della confezione originale.
    var fraction: Double {
        switch self {
        case .sealed:
            return 1
        case .plenty:
            return 0.75
        case .half:
            return 0.5
        case .low:
            return 0.2
        case .finished:
            return 0
        }
    }

    /// Gli stati che ha senso proporre a chi ha già aperto la confezione.
    static var openedCases: [PantryLevel] {
        [.plenty, .half, .low, .finished]
    }

    /// Lo stato che meglio descrive una frazione calcolata dalle ricette.
    static func closest(toFraction fraction: Double) -> PantryLevel {
        switch fraction {
        case ..<0.05:
            return .finished
        case ..<0.35:
            return .low
        case ..<0.65:
            return .half
        default:
            return .plenty
        }
    }
}

/// Una riga di dispensa: cosa c'è in casa, quanto, dove, fino a quando.
struct PantryItem: Identifiable, Hashable, Sendable {
    /// Soglia oltre la quale un prodotto non è più "in scadenza" ma solo fresco.
    static let expiringSoonThresholdDays = 3

    let id: String
    let userId: String
    /// Prepara la condivisione familiare: le query filtrano su `userId` finché è nil.
    var householdId: String?
    var productCatalogId: String?
    var name: LocalizedContent
    var brand: String?
    var quantity: PantryQuantity
    /// Quanto c'era nella confezione appena comprata: è il riferimento su cui
    /// si calcolano gli stati "metà", "poco".
    var initialQuantity: PantryQuantity
    var level: PantryLevel
    /// Quanto ci si può fidare di `quantity`. 1 = letta dallo scontrino,
    /// valori bassi = dedotta da ricette o dichiarata a occhio dall'utente.
    var quantityConfidence: Double
    var storage: PantryStorage
    var category: GrocerySpendingCategory
    var addedAt: Date
    var openedAt: Date?
    var expiresAt: Date?
    /// La data di scadenza è stimata dalla shelf life, non letta da confezione o scontrino.
    var isExpiryEstimated: Bool
    var source: PantrySource
    var sourceReferenceId: String?
    var notes: String?
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        householdId: String? = nil,
        productCatalogId: String? = nil,
        name: LocalizedContent,
        brand: String? = nil,
        quantity: PantryQuantity = .single,
        initialQuantity: PantryQuantity? = nil,
        level: PantryLevel = .sealed,
        quantityConfidence: Double = 1,
        storage: PantryStorage = .pantry,
        category: GrocerySpendingCategory = .other,
        addedAt: Date = Date(),
        openedAt: Date? = nil,
        expiresAt: Date? = nil,
        isExpiryEstimated: Bool = false,
        source: PantrySource = .manual,
        sourceReferenceId: String? = nil,
        notes: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.householdId = householdId
        self.productCatalogId = productCatalogId
        self.name = name
        self.brand = brand
        self.quantity = quantity
        self.initialQuantity = initialQuantity ?? quantity
        self.level = level
        self.quantityConfidence = min(1, max(0, quantityConfidence))
        self.storage = storage
        self.category = category
        self.addedAt = addedAt
        self.openedAt = openedAt
        self.expiresAt = expiresAt
        self.isExpiryEstimated = isExpiryEstimated
        self.source = source
        self.sourceReferenceId = sourceReferenceId
        self.notes = notes
        self.updatedAt = updatedAt
    }

    var displayName: String {
        name.resolved()
    }

    var isOpened: Bool {
        openedAt != nil
    }

    /// La quantità è una stima, non una misura: le ricette che chiedono grammi
    /// esatti devono dirlo invece di fingere certezza.
    var isQuantityEstimated: Bool {
        quantityConfidence < 0.9
    }

    /// Frazione di confezione ancora presente, per la barra di livello.
    var remainingFraction: Double {
        guard initialQuantity.valueInBaseUnit > 0 else { return level.fraction }
        return min(1, max(0, quantity.valueInBaseUnit / initialQuantity.valueInBaseUnit))
    }

    /// Applica uno stato dichiarato dall'utente: aggiorna la quantità di
    /// conseguenza e abbassa la confidenza, perché è una stima a occhio.
    func settingLevel(_ newLevel: PantryLevel, on date: Date = Date()) -> PantryItem {
        var updated = self
        updated.level = newLevel
        updated.quantity = PantryQuantity(
            value: initialQuantity.value * newLevel.fraction,
            unit: initialQuantity.unit
        )
        updated.quantityConfidence = newLevel == .sealed ? 1 : 0.6
        updated.updatedAt = date

        if newLevel != .sealed, updated.openedAt == nil {
            updated.openedAt = date
        }

        return updated
    }

    /// Riallinea lo stato dopo un consumo calcolato (una ricetta cucinata).
    func syncingLevelToQuantity() -> PantryItem {
        guard isOpened || level != .sealed else { return self }

        var updated = self
        updated.level = PantryLevel.closest(toFraction: remainingFraction)
        return updated
    }

    func daysUntilExpiry(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let expiresAt else { return nil }

        let today = calendar.startOfDay(for: referenceDate)
        let expiryDay = calendar.startOfDay(for: expiresAt)
        return calendar.dateComponents([.day], from: today, to: expiryDay).day
    }

    func freshness(referenceDate: Date = Date(), calendar: Calendar = .current) -> PantryFreshness {
        guard let days = daysUntilExpiry(referenceDate: referenceDate, calendar: calendar) else {
            return .unknown
        }

        if days < 0 {
            return .expired
        }

        if days <= Self.expiringSoonThresholdDays {
            return .expiringSoon(daysLeft: days)
        }

        return .fresh(daysLeft: days)
    }

    /// Due righe si fondono solo se sono lo stesso prodotto, nello stesso posto,
    /// e nessuna delle due è già aperta: unire un latte aperto a uno chiuso
    /// falserebbe la scadenza.
    func canMerge(with other: PantryItem) -> Bool {
        guard storage == other.storage,
              quantity.unit.kind == other.quantity.unit.kind,
              !isOpened, !other.isOpened else {
            return false
        }

        if let productCatalogId, let otherId = other.productCatalogId {
            return productCatalogId == otherId
        }

        return displayName.localizedCaseInsensitiveCompare(other.displayName) == .orderedSame
    }
}

// MARK: - Firestore

extension PantryItem {
    static func fromDocument(id: String, data: [String: Any]) -> PantryItem? {
        guard let userId = data["userId"] as? String,
              let name = LocalizedContent.decode(data["name"]) else {
            return nil
        }

        let unit = PantryUnit(rawValue: data["unit"] as? String ?? "") ?? .piece
        let quantity = PantryQuantity(
            value: groceryDoubleValue(from: data["quantity"], defaultValue: 1),
            unit: unit
        )
        let addedAt = groceryDateValue(from: data["addedAt"]) ?? Date()

        // I documenti scritti prima dei livelli non hanno questi campi: si
        // ricavano dalla quantità, che è sempre stata presente.
        let initialUnit = PantryUnit(rawValue: data["initialUnit"] as? String ?? "") ?? unit
        let initialQuantity = PantryQuantity(
            value: groceryDoubleValue(from: data["initialQuantity"], defaultValue: quantity.value),
            unit: initialUnit
        )

        return PantryItem(
            id: id,
            userId: userId,
            householdId: data["householdId"] as? String,
            productCatalogId: data["productCatalogId"] as? String,
            name: name,
            brand: data["brand"] as? String,
            quantity: quantity,
            initialQuantity: initialQuantity,
            level: PantryLevel(rawValue: data["level"] as? String ?? "") ?? .sealed,
            quantityConfidence: groceryDoubleValue(from: data["quantityConfidence"], defaultValue: 1),
            storage: PantryStorage(rawValue: data["storage"] as? String ?? "") ?? .pantry,
            category: GrocerySpendingCategory(rawValue: data["category"] as? String ?? "") ?? .other,
            addedAt: addedAt,
            openedAt: groceryDateValue(from: data["openedAt"]),
            expiresAt: groceryDateValue(from: data["expiresAt"]),
            isExpiryEstimated: data["isExpiryEstimated"] as? Bool ?? false,
            source: PantrySource(rawValue: data["source"] as? String ?? "") ?? .manual,
            sourceReferenceId: data["sourceReferenceId"] as? String,
            notes: data["notes"] as? String,
            updatedAt: groceryDateValue(from: data["updatedAt"]) ?? addedAt
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "name": name.documentValue,
            "quantity": quantity.value,
            "unit": quantity.unit.rawValue,
            "initialQuantity": initialQuantity.value,
            "initialUnit": initialQuantity.unit.rawValue,
            "level": level.rawValue,
            "quantityConfidence": quantityConfidence,
            "storage": storage.rawValue,
            "category": category.rawValue,
            "addedAt": Timestamp(date: addedAt),
            "isExpiryEstimated": isExpiryEstimated,
            "source": source.rawValue,
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let householdId { data["householdId"] = householdId }
        if let productCatalogId { data["productCatalogId"] = productCatalogId }
        if let brand { data["brand"] = brand }
        if let openedAt { data["openedAt"] = Timestamp(date: openedAt) }
        if let expiresAt { data["expiresAt"] = Timestamp(date: expiresAt) }
        if let sourceReferenceId { data["sourceReferenceId"] = sourceReferenceId }
        if let notes { data["notes"] = notes }

        return data
    }
}
