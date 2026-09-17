import Foundation

/// Testo che vive nel database, non nello String Catalog.
///
/// Nomi prodotto, titoli ricetta, categorie del catalogo: contenuto che cresce
/// nel tempo e non può essere tradotto a compile time. Firestore lo memorizza
/// come mappa `{"it": "Latte intero", "en": "Whole milk"}`.
///
/// I documenti creati prima dell'introduzione dell'i18n contengono una stringa
/// semplice: `decode(_:)` la accetta e la interpreta come `sourceLanguage`,
/// così la migrazione è progressiva e non serve un backfill.
struct LocalizedContent: Hashable, Sendable {
    /// Lingua in cui il contenuto viene creato di default.
    static let sourceLanguage = "it"

    private(set) var values: [String: String]

    init(_ values: [String: String]) {
        self.values = values.filter { !$0.value.trimmed.isEmpty }
    }

    init(source: String) {
        self.init([Self.sourceLanguage: source])
    }

    var isEmpty: Bool { values.isEmpty }

    /// Testo nella lingua richiesta, con catena di fallback:
    /// lingua+regione → lingua → lingua sorgente → inglese → primo disponibile.
    func resolved(for locale: Locale = .autoupdatingCurrent) -> String {
        for candidate in Self.candidateKeys(for: locale) {
            if let value = values[candidate], !value.trimmed.isEmpty {
                return value
            }
        }

        return values.values.first { !$0.trimmed.isEmpty } ?? ""
    }

    /// Corpus per la ricerca: l'utente può cercare "milk" anche con app in italiano.
    var searchableCorpus: [String] {
        Array(values.values)
    }

    func withValue(_ value: String, for languageCode: String) -> LocalizedContent {
        var updated = values
        updated[languageCode] = value
        return LocalizedContent(updated)
    }

    // MARK: - Firestore

    /// Accetta sia la mappa localizzata sia la stringa singola dei documenti legacy.
    static func decode(_ raw: Any?) -> LocalizedContent? {
        if let map = raw as? [String: String] {
            let content = LocalizedContent(map)
            return content.isEmpty ? nil : content
        }

        if let map = raw as? [String: Any] {
            let strings = map.compactMapValues { $0 as? String }
            let content = LocalizedContent(strings)
            return content.isEmpty ? nil : content
        }

        if let single = raw as? String, !single.trimmed.isEmpty {
            return LocalizedContent(source: single)
        }

        return nil
    }

    var documentValue: [String: String] {
        values
    }
}

extension LocalizedContent {
    static func candidateKeys(for locale: Locale) -> [String] {
        var keys: [String] = []

        if let language = locale.language.languageCode?.identifier {
            if let region = locale.region?.identifier {
                keys.append("\(language)-\(region)")
            }
            keys.append(language)
        }

        keys.append(sourceLanguage)
        keys.append("en")

        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
