import Foundation

/// Trasforma le osservazioni grezze nei prezzi che l'app mostra.
///
/// Non è una media: è una mediana su una finestra recente. Un OCR che legge
/// "12,90" invece di "1,29" una volta sola non deve spostare il prezzo del
/// latte, e con la mediana non lo fa.
struct PriceObservationAggregator: Sendable {
    /// Oltre questa età un'osservazione non partecipa più al prezzo mostrato.
    let windowDays: Double
    /// Quante osservazioni recenti concorrono alla mediana.
    let sampleSize: Int
    let halfLifeDays: Double

    init(windowDays: Double = 90, sampleSize: Int = 5, halfLifeDays: Double = 21) {
        self.windowDays = windowDays
        self.sampleSize = sampleSize
        self.halfLifeDays = halfLifeDays
    }

    func aggregate(_ observations: [PriceObservation], on date: Date = Date()) -> [RetailerProductPrice] {
        let usable = observations.filter { observation in
            observation.isUsable && age(of: observation, on: date) <= windowDays
        }

        let grouped = Dictionary(grouping: usable) { observation in
            GroupKey(retailerId: observation.retailerId, productCatalogId: observation.productCatalogId ?? observation.gtin ?? "")
        }

        return grouped.compactMap { key, group in
            makePrice(key: key, observations: group, on: date)
        }
        .sorted { $0.id < $1.id }
    }

    private func makePrice(key: GroupKey, observations: [PriceObservation], on date: Date) -> RetailerProductPrice? {
        guard !key.productCatalogId.isEmpty else { return nil }

        let recent = observations
            .sorted { $0.observedAt > $1.observedAt }
            .prefix(sampleSize)

        guard let newest = recent.first else { return nil }

        let prices = recent.map(\.effectivePrice).sorted()
        guard let medianPrice = median(of: prices) else { return nil }

        // Il promo si dichiara solo se l'osservazione più recente lo aveva:
        // uno sconto vecchio non è uno sconto.
        let promoPrice = newest.promoPrice.map { _ in medianPrice }

        return RetailerProductPrice(
            id: "\(key.retailerId)__\(key.productCatalogId)",
            retailerId: key.retailerId,
            productCatalogId: key.productCatalogId,
            basePrice: newest.promoPrice != nil ? newest.price : medianPrice,
            promoPrice: promoPrice,
            loyaltyPrice: nil,
            currency: newest.currency,
            isAvailable: true,
            lastUpdatedAt: newest.observedAt,
            sourceType: newest.source,
            sourceConfidence: newest.confidence(on: date, halfLifeDays: halfLifeDays)
        )
    }

    private func age(of observation: PriceObservation, on date: Date) -> Double {
        max(0, date.timeIntervalSince(observation.observedAt) / 86_400)
    }

    private func median(of sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }

        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private struct GroupKey: Hashable {
        let retailerId: String
        let productCatalogId: String
    }
}
