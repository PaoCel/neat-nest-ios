import Foundation
import FirebaseFirestore

/// Un prezzo visto una volta, in un posto, in un giorno.
///
/// È il mattone su cui si costruiscono i prezzi mostrati: non si scrive mai
/// "il latte costa 1,29" ma "il 24 agosto, all'Esselunga di via Roma, qualcuno
/// ha pagato il latte 1,29". I prezzi in `retailerProductPrices` diventano una
/// vista derivata da queste osservazioni.
///
/// La collection è **append-only** e non contiene l'identità di chi contribuisce:
/// il prezzo non è un dato personale, ma il carrello di una persona lo è.
struct PriceObservation: Identifiable, Hashable, Sendable {
    let id: String
    let retailerId: String
    /// Punto vendita specifico, quando lo si conosce: i prezzi variano fra negozi
    /// della stessa insegna.
    let storeId: String?
    let productCatalogId: String?
    /// Codice a barre, quando disponibile: è l'aggancio più affidabile.
    let gtin: String?
    /// Testo grezzo della riga di scontrino, per poter rifare il matching dopo.
    let rawLabel: String
    let price: Double
    let promoPrice: Double?
    let currency: String
    let observedAt: Date
    let source: RetailerPriceSourceType

    init(
        id: String = UUID().uuidString,
        retailerId: String,
        storeId: String? = nil,
        productCatalogId: String? = nil,
        gtin: String? = nil,
        rawLabel: String,
        price: Double,
        promoPrice: Double? = nil,
        currency: String = "EUR",
        observedAt: Date = Date(),
        source: RetailerPriceSourceType = .receipt
    ) {
        self.id = id
        self.retailerId = retailerId
        self.storeId = storeId
        self.productCatalogId = productCatalogId
        self.gtin = gtin
        self.rawLabel = rawLabel
        self.price = price
        self.promoPrice = promoPrice
        self.currency = currency
        self.observedAt = observedAt
        self.source = source
    }

    var effectivePrice: Double {
        promoPrice ?? price
    }

    /// Un'osservazione è utile solo se ha un prezzo sensato e un aggancio al
    /// catalogo: senza quello non si può confrontare con niente.
    var isUsable: Bool {
        price > 0 && (productCatalogId != nil || gtin != nil)
    }

    /// Quanto vale oggi. La fiducia parte dalla fonte e decade con i giorni:
    /// dopo `halfLifeDays` vale metà.
    func confidence(on date: Date = Date(), halfLifeDays: Double = 21) -> Double {
        let ageDays = max(0, date.timeIntervalSince(observedAt) / 86_400)
        let decay = pow(0.5, ageDays / halfLifeDays)
        return min(1, max(0, source.baseConfidence * decay))
    }
}

// MARK: - Firestore

extension PriceObservation {
    static func fromDocument(id: String, data: [String: Any]) -> PriceObservation? {
        guard let retailerId = data["retailerId"] as? String,
              let rawLabel = data["rawLabel"] as? String else {
            return nil
        }

        let price = groceryDoubleValue(from: data["price"])
        guard price > 0 else { return nil }

        return PriceObservation(
            id: id,
            retailerId: retailerId,
            storeId: data["storeId"] as? String,
            productCatalogId: data["productCatalogId"] as? String,
            gtin: data["gtin"] as? String,
            rawLabel: rawLabel,
            price: price,
            promoPrice: data["promoPrice"].flatMap {
                let value = groceryDoubleValue(from: $0)
                return value > 0 ? value : nil
            },
            currency: data["currency"] as? String ?? "EUR",
            observedAt: groceryDateValue(from: data["observedAt"]) ?? Date(),
            source: RetailerPriceSourceType.from(rawValue: data["source"] as? String)
        )
    }

    var documentData: [String: Any] {
        var data: [String: Any] = [
            "retailerId": retailerId,
            "rawLabel": rawLabel,
            "price": price,
            "currency": currency,
            "observedAt": Timestamp(date: observedAt),
            "source": source.rawValue
        ]

        if let storeId { data["storeId"] = storeId }
        if let productCatalogId { data["productCatalogId"] = productCatalogId }
        if let gtin { data["gtin"] = gtin }
        if let promoPrice { data["promoPrice"] = promoPrice }

        return data
    }
}
