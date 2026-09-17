import Foundation

/// Un acquisto osservato: cosa, quando.
struct PurchaseEvent: Hashable, Sendable {
    let productKey: String
    let displayName: String
    let date: Date
}

/// "Questo di solito lo ricompri ogni dieci giorni, e sono passati quattordici."
struct RepurchaseSuggestion: Identifiable, Hashable, Sendable {
    var id: String { productKey }

    let productKey: String
    let displayName: String
    let typicalIntervalDays: Int
    let lastPurchase: Date
    let daysSinceLastPurchase: Int
    /// Quanto è regolare questo acquisto: poche osservazioni o intervalli
    /// ballerini abbassano la fiducia.
    let confidence: Double

    /// Quanto è in ritardo rispetto al solito, da 0 in su.
    var overdueRatio: Double {
        guard typicalIntervalDays > 0 else { return 0 }
        return Double(daysSinceLastPurchase) / Double(typicalIntervalDays)
    }
}

/// Deduce ogni quanto ricompri le cose.
///
/// È volutamente prudente. Non tutti gli acquisti passano dall'app: fai la
/// spesa, non scansioni lo scontrino, e la storia si buca. Un algoritmo severo
/// in quelle condizioni inizia a suggerirti di ricomprare il latte che hai già
/// in frigo, e a quel punto l'utente smette di leggere i suggerimenti.
///
/// Quindi: mediana invece di media, tolleranza sul ritardo, e silenzio quando
/// i dati non bastano.
struct RepurchasePredictor: Sendable {
    /// Sotto due acquisti non esiste un intervallo.
    static let minimumPurchases = 2
    /// Intervalli fuori da questa forbice sono rumore, non abitudini.
    static let minIntervalDays = 2.0
    static let maxIntervalDays = 180.0
    /// Si aspetta un 15% oltre il solito prima di parlare.
    static let overdueTolerance = 1.15
    /// Sotto questa fiducia si tace: meglio nessun suggerimento che uno sbagliato.
    static let minimumConfidence = 0.35

    func suggestions(
        from purchases: [PurchaseEvent],
        pantry: [PantryItem] = [],
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> [RepurchaseSuggestion] {
        let inPantry = Set(pantryKeys(pantry))

        return Dictionary(grouping: purchases, by: \.productKey)
            .compactMap { key, events -> RepurchaseSuggestion? in
                // Ce l'hai ancora: non è il momento di ricomprarlo.
                guard !inPantry.contains(key) else { return nil }
                return makeSuggestion(key: key, events: events, on: date, calendar: calendar)
            }
            .filter { $0.confidence >= Self.minimumConfidence }
            .filter { $0.overdueRatio >= Self.overdueTolerance }
            .sorted { $0.overdueRatio > $1.overdueRatio }
    }

    /// Anche senza ritardo può servire sapere ogni quanto si ricompra una cosa.
    func interval(for productKey: String, in purchases: [PurchaseEvent]) -> Int? {
        let events = purchases.filter { $0.productKey == productKey }
        guard let intervals = intervals(of: events), let median = median(of: intervals) else { return nil }
        return Int(median.rounded())
    }

    // MARK: - Calcolo

    private func makeSuggestion(
        key: String,
        events: [PurchaseEvent],
        on date: Date,
        calendar: Calendar
    ) -> RepurchaseSuggestion? {
        let sorted = events.sorted { $0.date < $1.date }

        guard sorted.count >= Self.minimumPurchases,
              let last = sorted.last,
              let intervals = intervals(of: sorted),
              let median = median(of: intervals) else {
            return nil
        }

        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last.date),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        guard daysSince >= 0 else { return nil }

        return RepurchaseSuggestion(
            productKey: key,
            displayName: last.displayName,
            typicalIntervalDays: Int(median.rounded()),
            lastPurchase: last.date,
            daysSinceLastPurchase: daysSince,
            confidence: confidence(for: intervals, median: median)
        )
    }

    /// Giorni fra un acquisto e il successivo, scartando quelli implausibili.
    private func intervals(of sortedEvents: [PurchaseEvent]) -> [Double]? {
        guard sortedEvents.count >= Self.minimumPurchases else { return nil }

        let gaps = zip(sortedEvents, sortedEvents.dropFirst()).map { previous, next in
            next.date.timeIntervalSince(previous.date) / 86_400
        }
        .filter { $0 >= Self.minIntervalDays && $0 <= Self.maxIntervalDays }

        return gaps.isEmpty ? nil : gaps
    }

    /// Cresce col numero di osservazioni e cala quando gli intervalli sono
    /// irregolari: chi compra il caffè ogni 30 giorni preciso è credibile, chi
    /// lo compra a 5, 40 e 90 giorni no.
    private func confidence(for intervals: [Double], median: Double) -> Double {
        let sampleScore = min(1, Double(intervals.count) / 4)

        guard median > 0, intervals.count > 1 else { return sampleScore * 0.6 }

        let deviations = intervals.map { abs($0 - median) / median }
        let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)
        let regularity = max(0, 1 - averageDeviation)

        return min(1, sampleScore * (0.4 + 0.6 * regularity))
    }

    private func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }

        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// Un prodotto conta come "presente" solo se ne resta qualcosa.
    private func pantryKeys(_ pantry: [PantryItem]) -> [String] {
        pantry.compactMap { item in
            guard item.level != .finished, !item.quantity.isEmpty else { return nil }
            return item.productCatalogId ?? RepurchasePredictor.normalizedKey(item.displayName)
        }
    }

    /// Chiave stabile per i prodotti che non hanno un id di catalogo.
    static func normalizedKey(_ name: String) -> String {
        RecipeTextNormalizer.tokens(from: name).sorted().joined(separator: "-")
    }

    /// Trasforma le righe di scontrino in acquisti confrontabili nel tempo.
    static func purchaseEvents(from lineItems: [ReceiptLineItem], receiptDates: [String: Date]) -> [PurchaseEvent] {
        lineItems.compactMap { line in
            guard let date = receiptDates[line.receiptImportId] else { return nil }

            let name = line.normalizedName.trimmed.isEmpty ? line.rawLineText.trimmed : line.normalizedName.trimmed
            guard !name.isEmpty else { return nil }

            return PurchaseEvent(
                productKey: line.productCatalogId ?? normalizedKey(name),
                displayName: name,
                date: date
            )
        }
    }
}
