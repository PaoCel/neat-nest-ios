import Foundation

/// La pezzatura scritta nel nome del prodotto: "RICOTTA 250G", "LATTE 1L",
/// "TONNO 3X80G".
///
/// Serve a rendere confrontabili scontrino e ricetta. Lo scontrino dice
/// "1 pezzo di ricotta", la ricetta chiede "200 g": senza pezzatura sono due
/// grandezze che non si parlano. Con la pezzatura, un pezzo *è* 250 g.
struct PackageSize: Hashable, Sendable {
    /// Contenuto di una singola confezione (80 g in "3x80g").
    let unitQuantity: PantryQuantity
    /// Quante confezioni nel pacco multiplo (3 in "3x80g").
    let packCount: Int

    init(unitQuantity: PantryQuantity, packCount: Int = 1) {
        self.unitQuantity = unitQuantity
        self.packCount = max(1, packCount)
    }

    /// Contenuto totale della confezione venduta.
    var totalQuantity: PantryQuantity {
        PantryQuantity(value: unitQuantity.value * Double(packCount), unit: unitQuantity.unit)
    }

    var isMultipack: Bool { packCount > 1 }
}

/// Estrae la pezzatura dal nome di un prodotto.
///
/// Lavora su testo da scontrino, quindi tollera maiuscole, abbreviazioni e
/// spaziature irregolari. Quando non è sicura non inventa: restituisce `nil` e
/// il prodotto resta contato a pezzi.
enum PackageSizeParser {
    /// Unità scritte come compaiono sugli scontrini, mappate su quelle interne.
    /// L'ordine conta: "kg" va provato prima di "g", "ml" prima di "l".
    private static let unitAliases: [(tokens: [String], unit: PantryUnit, factor: Double)] = [
        (["kg", "kilogrammi", "chilogrammi"], .kilogram, 1),
        (["gr", "grammi", "g"], .gram, 1),
        (["ml", "millilitri"], .milliliter, 1),
        (["cl", "centilitri"], .milliliter, 10),
        (["lt", "litri", "litro", "l"], .liter, 1)
    ]

    static func parse(_ text: String) -> PackageSize? {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: "×", with: "x")

        if let multipack = parseMultipack(in: normalized) {
            return multipack
        }

        if let single = parseSingle(in: normalized) {
            return PackageSize(unitQuantity: single)
        }

        return nil
    }

    /// Applica la pezzatura a una riga di scontrino.
    ///
    /// "2 x RICOTTA 250G" diventa 500 g, non 2 pezzi. Se la pezzatura non si
    /// legge, resta il conteggio a pezzi che è comunque corretto.
    static func quantity(forLineText text: String, receiptQuantity: Double) -> PantryQuantity {
        let pieces = max(1, receiptQuantity)

        guard let size = parse(text) else {
            return PantryQuantity(value: pieces, unit: .piece)
        }

        let total = size.totalQuantity
        return PantryQuantity(value: total.value * pieces, unit: total.unit)
    }
}

// MARK: - Riconoscimento

private extension PackageSizeParser {
    /// "3x80g", "6 X 0,5 L"
    static func parseMultipack(in text: String) -> PackageSize? {
        for (tokens, unit, factor) in unitAliases {
            for token in tokens {
                let pattern = #"(\d{1,2})\s*x\s*(\d+(?:[.,]\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: token) + #"(?![a-z])"#

                guard let match = firstMatch(pattern: pattern, in: text),
                      let count = Int(match.groups[0]),
                      let value = number(from: match.groups[1]),
                      count > 0, value > 0 else {
                    continue
                }

                return PackageSize(
                    unitQuantity: PantryQuantity(value: value * factor, unit: unit),
                    packCount: count
                )
            }
        }

        return nil
    }

    /// "250g", "1,5 lt", "conf. 500 ml"
    static func parseSingle(in text: String) -> PantryQuantity? {
        for (tokens, unit, factor) in unitAliases {
            for token in tokens {
                // Il numero non deve essere preceduto da "x", o si mangerebbe
                // il secondo membro di un multipack.
                let pattern = #"(?<![x\d])(\d+(?:[.,]\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: token) + #"(?![a-z])"#

                guard let match = firstMatch(pattern: pattern, in: text),
                      let value = number(from: match.groups[0]),
                      value > 0 else {
                    continue
                }

                return PantryQuantity(value: value * factor, unit: unit)
            }
        }

        return nil
    }

    struct RegexMatch {
        let groups: [String]
    }

    static func firstMatch(pattern: String, in text: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            groups.append(String(text[range]))
        }

        return RegexMatch(groups: groups)
    }

    static func number(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
