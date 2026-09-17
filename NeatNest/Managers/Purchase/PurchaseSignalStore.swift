import Foundation

/// Conserva gli indizi di acquisto sul dispositivo.
///
/// Restano **in locale**: dove passi e quanto spendi non hanno motivo di
/// viaggiare verso un server finché non sei tu a registrare la spesa. Vengono
/// anche buttati via presto: sono un promemoria, non uno storico.
actor PurchaseSignalStore {
    /// Oltre questo, un indizio non serve più a niente: o l'hai registrato o
    /// non ti interessava.
    static let retention: TimeInterval = 24 * 60 * 60

    private let fileURL: URL
    private var cached: [PurchaseSignal]?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? FileManager.default.temporaryDirectory

            self.fileURL = directory.appendingPathComponent("purchase-signals.json")
        }
    }

    func record(_ signal: PurchaseSignal) -> [PurchaseSignal] {
        var signals = load()
        signals.append(signal)
        signals = prune(signals)
        save(signals)
        return signals
    }

    func all() -> [PurchaseSignal] {
        prune(load())
    }

    /// Chiude gli indizi di una richiesta a cui l'utente ha risposto, in un
    /// senso o nell'altro.
    func resolve(promptId: String) {
        let handledIds = Set(promptId.components(separatedBy: "+"))
        save(load().filter { !handledIds.contains($0.id) })
    }

    func clear() {
        save([])
    }

    // MARK: - Persistenza

    private func load() -> [PurchaseSignal] {
        if let cached { return cached }

        guard let data = try? Data(contentsOf: fileURL),
              let signals = try? JSONDecoder().decode([PurchaseSignal].self, from: data) else {
            cached = []
            return []
        }

        cached = signals
        return signals
    }

    private func save(_ signals: [PurchaseSignal]) {
        cached = signals

        guard let data = try? JSONEncoder().encode(signals) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private func prune(_ signals: [PurchaseSignal]) -> [PurchaseSignal] {
        let cutoff = Date().addingTimeInterval(-Self.retention)
        return signals.filter { $0.detectedAt >= cutoff }
    }
}
