import Foundation

/// Una riga di scontrino riconosciuta dall'OCR.
struct ParsedReceiptLine: Hashable, Sendable {
    let rawText: String
    var quantity: Double
    var unitPrice: Double?
    var lineTotal: Double
}

/// Quello che si riesce a capire di uno scontrino fotografato.
struct ParsedReceipt: Hashable, Sendable {
    var retailerName: String?
    var purchaseDate: Date?
    var declaredTotal: Double?
    var lines: [ParsedReceiptLine]

    var computedTotal: Double {
        lines.reduce(0) { $0 + $1.lineTotal }
    }

    /// La somma delle righe torna con il totale stampato? Se no qualcosa è
    /// sfuggito all'OCR, e conviene dirlo all'utente invece di fingere.
    var isConsistent: Bool {
        guard let declaredTotal, declaredTotal > 0 else { return true }
        return abs(declaredTotal - computedTotal) <= max(0.05, declaredTotal * 0.02)
    }

    static let empty = ParsedReceipt(retailerName: nil, purchaseDate: nil, declaredTotal: nil, lines: [])
}

/// Trasforma le righe di testo dell'OCR in righe di scontrino.
///
/// Non conosce Vision né le immagini: prende stringhe e restituisce modelli,
/// così è testabile senza fotocamera.
struct ReceiptTextParser: Sendable {
    /// Righe che non sono articoli: totali, pagamenti, intestazioni fiscali.
    private static let noiseKeywords: [String] = [
        "totale", "subtotale", "importo", "contante", "contanti", "resto",
        "iva", "aliquota", "carta", "bancomat", "pos", "pagamento",
        "scontrino", "documento commerciale", "cassa", "cassiere", "operatore",
        "saldo", "punti", "fidelity", "arrivederci", "grazie", "partita iva",
        "matricola", "num.", "pezzi totali", "www.", "tel."
    ]

    private static let totalKeywords = ["totale complessivo", "totale euro", "totale"]

    init() { }

    func parse(lines rawLines: [String], referenceDate: Date = Date()) -> ParsedReceipt {
        let cleaned = rawLines
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        var lines: [ParsedReceiptLine] = []
        var declaredTotal: Double?

        for line in cleaned {
            let lower = line.lowercased()

            if declaredTotal == nil, let total = totalValue(in: line, lower: lower) {
                declaredTotal = total
                continue
            }

            guard !isNoise(lower), let price = trailingPrice(in: line) else { continue }

            let description = String(line.dropLast(price.matchedText.count)).trimmed
            guard looksLikeProductName(description) else { continue }

            let (quantity, unitPrice) = quantityAndUnitPrice(in: description, lineTotal: price.value)

            lines.append(
                ParsedReceiptLine(
                    rawText: cleanDescription(description),
                    quantity: quantity,
                    unitPrice: unitPrice,
                    lineTotal: price.value
                )
            )
        }

        return ParsedReceipt(
            retailerName: retailerName(from: cleaned),
            purchaseDate: date(from: cleaned) ?? referenceDate,
            declaredTotal: declaredTotal,
            lines: lines.filter { $0.lineTotal > 0 }
        )
    }
}

// MARK: - Riconoscimento dei pezzi

private extension ReceiptTextParser {
    struct PriceMatch {
        let value: Double
        let matchedText: String
    }

    func isNoise(_ lowercased: String) -> Bool {
        Self.noiseKeywords.contains { lowercased.contains($0) }
    }

    /// Un articolo ha un nome: almeno tre lettere.
    func looksLikeProductName(_ text: String) -> Bool {
        text.filter { $0.isLetter }.count >= 3
    }

    /// Prezzo a fine riga, con eventuale lettera di reparto: "PANE 2,45 A".
    func trailingPrice(in line: String) -> PriceMatch? {
        firstMatch(pattern: #"(\d{1,4}[.,]\d{2})\s*[A-Za-z]?\s*$"#, in: line)
    }

    func totalValue(in line: String, lower: String) -> Double? {
        guard Self.totalKeywords.contains(where: { lower.contains($0) }) else { return nil }
        return trailingPrice(in: line)?.value
    }

    func firstMatch(pattern: String, in line: String) -> PriceMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valueRange = Range(match.range(at: 1), in: line),
              let fullRange = Range(match.range, in: line) else {
            return nil
        }

        let normalized = line[valueRange].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }

        return PriceMatch(value: value, matchedText: String(line[fullRange]))
    }

    /// Riconosce "2 x 1,29" e "3 PANE".
    func quantityAndUnitPrice(in description: String, lineTotal: Double) -> (Double, Double?) {
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,3})\s*[xX×]\s*(\d{1,4}[.,]\d{2})"#),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let quantityRange = Range(match.range(at: 1), in: description),
           let priceRange = Range(match.range(at: 2), in: description),
           let quantity = Double(description[quantityRange]),
           let unitPrice = Double(description[priceRange].replacingOccurrences(of: ",", with: ".")),
           quantity > 0 {
            return (quantity, unitPrice)
        }

        if let regex = try? NSRegularExpression(pattern: #"^(\d{1,2})\s+\p{L}"#),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let range = Range(match.range(at: 1), in: description),
           let quantity = Double(description[range]),
           quantity > 0, quantity <= 20 {
            return (quantity, lineTotal / quantity)
        }

        return (1, lineTotal)
    }

    func cleanDescription(_ description: String) -> String {
        var text = description

        for pattern in [#"\d{1,3}\s*[xX×]\s*\d{1,4}[.,]\d{2}"#, #"^\d{1,2}\s+"#, #"^[*#-]+\s*"#, #"\s{2,}"#] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return text.trimmed
    }

    /// L'insegna sta in cima, prima dei dati fiscali.
    func retailerName(from lines: [String]) -> String? {
        for line in lines.prefix(5) {
            guard !isNoise(line.lowercased()),
                  looksLikeProductName(line),
                  trailingPrice(in: line) == nil else {
                continue
            }
            return line
        }
        return nil
    }

    func date(from lines: [String]) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{2})[/.-](\d{2})[/.-](\d{2,4})"#) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        for line in lines {
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let dayRange = Range(match.range(at: 1), in: line),
                  let monthRange = Range(match.range(at: 2), in: line),
                  let yearRange = Range(match.range(at: 3), in: line),
                  let day = Int(line[dayRange]),
                  let month = Int(line[monthRange]),
                  var year = Int(line[yearRange]) else {
                continue
            }

            if year < 100 { year += 2000 }
            guard (1...31).contains(day), (1...12).contains(month) else { continue }

            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = year
            return calendar.date(from: components)
        }

        return nil
    }
}
