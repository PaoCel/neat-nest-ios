import Foundation

/// Un articolo estratto da una frase libera.
struct GroceryDraftItem: Hashable, Sendable {
    var name: String
    var quantity: Double
    var unit: String?

    var draft: GroceryItemDraft {
        GroceryItemDraft(rawInputText: name, quantity: quantity, unit: unit, notes: nil)
    }
}

/// Spezza "due litri di latte, il pane e sei uova" in tre articoli.
///
/// Deterministico e senza rete: è la base che funziona su ogni iPhone, e resta
/// il fallback quando il modello on-device non è disponibile.
struct GroceryPhraseParser: Sendable {
    /// Numeri scritti a parole, come li dice chi parla a Siri.
    private static let numberWords: [String: Double] = [
        "un": 1, "uno": 1, "una": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5,
        "sei": 6, "sette": 7, "otto": 8, "nove": 9, "dieci": 10, "undici": 11,
        "dodici": 12, "mezzo": 0.5, "mezza": 0.5,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6
    ]

    /// Unità riconosciute e la forma con cui vengono memorizzate.
    private static let unitWords: [String: String] = [
        "l": "l", "lt": "l", "litro": "l", "litri": "l",
        "ml": "ml", "millilitri": "ml",
        "kg": "kg", "chilo": "kg", "chili": "kg", "chilogrammi": "kg",
        "g": "g", "gr": "g", "grammo": "g", "grammi": "g",
        "confezione": "conf", "confezioni": "conf", "pacco": "conf", "pacchi": "conf",
        "bottiglia": "bottiglia", "bottiglie": "bottiglia",
        "barattolo": "barattolo", "barattoli": "barattolo"
    ]

    /// Parole che non fanno parte del nome del prodotto.
    private static let leadingNoise: Set<String> = [
        "il", "lo", "la", "i", "gli", "le", "un", "uno", "una", "del", "della",
        "dello", "dei", "degli", "delle", "di", "d", "the", "a", "an",
        "compra", "comprare", "prendi", "prendere", "aggiungi", "serve", "servono"
    ]

    init() { }

    /// Divide la frase e interpreta ogni pezzo.
    func parse(_ text: String) -> [GroceryDraftItem] {
        segments(in: text)
            .compactMap { makeItem(from: $0) }
    }

    /// A capo, virgole, punti e virgola e la "e" fra due cose sono tutti
    /// separatori: è come parla la gente.
    func segments(in text: String) -> [String] {
        let separated = text
            .replacingOccurrences(of: "\n", with: ",")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: #"\s+e\s+"#, with: ",", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+and\s+"#, with: ",", options: [.regularExpression, .caseInsensitive])

        return separated
            .components(separatedBy: ",")
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
    }

    private func makeItem(from segment: String) -> GroceryDraftItem? {
        var tokens = segment
            .components(separatedBy: .whitespaces)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return nil }

        var quantity: Double = 1
        var unit: String?

        // La quantità, se c'è, sta davanti: "due litri di latte", "500 g farina".
        if let value = number(from: tokens[0]) {
            quantity = value
            tokens.removeFirst()

            if let first = tokens.first, let matchedUnit = Self.unitWords[normalized(first)] {
                unit = matchedUnit
                tokens.removeFirst()
            }
        }

        // Articoli e verbi non sono il nome del prodotto.
        while let first = tokens.first, Self.leadingNoise.contains(normalized(first)) {
            tokens.removeFirst()
        }

        let name = tokens.joined(separator: " ").trimmed
        guard name.count >= 2 else { return nil }

        return GroceryDraftItem(name: name, quantity: max(quantity, 0.01), unit: unit)
    }

    private func number(from token: String) -> Double? {
        let cleaned = normalized(token)

        if let word = Self.numberWords[cleaned] {
            return word
        }

        // "500g" attaccato: il numero c'è, l'unità la legge PackageSizeParser.
        let digits = cleaned.prefix { $0.isNumber || $0 == "," || $0 == "." }
        guard !digits.isEmpty, digits.count == cleaned.count else {
            return Double(cleaned.replacingOccurrences(of: ",", with: "."))
        }

        return Double(digits.replacingOccurrences(of: ",", with: "."))
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}
