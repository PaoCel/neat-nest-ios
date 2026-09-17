import Foundation

/// Unità in cui l'utente pensa la quantità di un prodotto in dispensa.
///
/// Il valore memorizzato non viene mai convertito: si salva ciò che l'utente ha
/// inserito. La conversione avviene solo in presentazione, così un utente con
/// locale `en_US` legge "1.1 lb" dove l'italiano legge "500 g".
enum PantryUnit: String, CaseIterable, Identifiable, Hashable, Sendable {
    case gram
    case kilogram
    case milliliter
    case liter
    case piece
    case pack

    var id: String { rawValue }

    enum Kind: Hashable, Sendable {
        case mass
        case volume
        case count
    }

    var kind: Kind {
        switch self {
        case .gram, .kilogram:
            return .mass
        case .milliliter, .liter:
            return .volume
        case .piece, .pack:
            return .count
        }
    }

    var massUnit: UnitMass? {
        switch self {
        case .gram:
            return .grams
        case .kilogram:
            return .kilograms
        default:
            return nil
        }
    }

    var volumeUnit: UnitVolume? {
        switch self {
        case .milliliter:
            return .milliliters
        case .liter:
            return .liters
        default:
            return nil
        }
    }

    /// Unità di riferimento della stessa famiglia, usata per sommare e confrontare
    /// quantità inserite con unità diverse (500 g + 1 kg).
    var baseUnit: PantryUnit {
        switch kind {
        case .mass:
            return .gram
        case .volume:
            return .milliliter
        case .count:
            return .piece
        }
    }

    /// Quanto vale una unità espressa nella `baseUnit` della sua famiglia.
    var baseUnitFactor: Double {
        switch self {
        case .gram, .milliliter, .piece:
            return 1
        case .kilogram, .liter:
            return 1000
        case .pack:
            return 1
        }
    }

    /// Etichetta per i picker. Le unità di massa e volume passano dal formatter
    /// di sistema, così seguono il locale invece di essere scritte a mano.
    var pickerLabel: String {
        switch kind {
        case .mass:
            guard let massUnit else { return rawValue }
            return Measurement(value: 1, unit: massUnit)
                .formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.significantDigits(0))))
        case .volume:
            guard let volumeUnit else { return rawValue }
            return Measurement(value: 1, unit: volumeUnit)
                .formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.significantDigits(0))))
        case .count:
            switch self {
            case .pack:
                return String(localized: "pantry.unit.pack.label", defaultValue: "Confezione")
            default:
                return String(localized: "pantry.unit.piece.label", defaultValue: "Pezzo")
            }
        }
    }

    /// Unità proposte per una categoria: evita di far scorrere grammi a chi sta
    /// aggiungendo uova.
    static func suggested(for kind: Kind) -> [PantryUnit] {
        allCases.filter { $0.kind == kind }
    }
}

/// Quantità di un prodotto: valore + unità, con aritmetica sulla famiglia comune.
struct PantryQuantity: Hashable, Sendable {
    var value: Double
    var unit: PantryUnit

    init(value: Double, unit: PantryUnit) {
        self.value = value
        self.unit = unit
    }

    static let single = PantryQuantity(value: 1, unit: .piece)

    var isEmpty: Bool { value <= 0.0001 }

    var valueInBaseUnit: Double {
        value * unit.baseUnitFactor
    }

    /// Somma possibile solo fra unità della stessa famiglia; `pack` resta a sé
    /// perché due confezioni diverse non sono sommabili in modo sensato.
    func adding(_ other: PantryQuantity) -> PantryQuantity? {
        guard unit.kind == other.unit.kind else { return nil }
        guard unit != .pack, other.unit != .pack else {
            return unit == other.unit ? PantryQuantity(value: value + other.value, unit: unit) : nil
        }

        let total = valueInBaseUnit + other.valueInBaseUnit
        return PantryQuantity(value: total / unit.baseUnitFactor, unit: unit)
    }

    func subtracting(_ other: PantryQuantity) -> PantryQuantity? {
        guard let negated = adding(PantryQuantity(value: -other.value, unit: other.unit)) else { return nil }
        return PantryQuantity(value: max(0, negated.value), unit: negated.unit)
    }

    /// Copre la quantità richiesta da una ricetta? Usato dal match dispensa↔ricette.
    func covers(_ required: PantryQuantity) -> Bool {
        guard unit.kind == required.unit.kind else { return false }
        return valueInBaseUnit + 0.0001 >= required.valueInBaseUnit
    }

    func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        switch unit.kind {
        case .mass:
            guard let massUnit = unit.massUnit else { return fallbackFormatted(locale: locale) }
            return Measurement(value: value, unit: massUnit)
                .formatted(.measurement(width: .abbreviated, usage: .general).locale(locale))
        case .volume:
            guard let volumeUnit = unit.volumeUnit else { return fallbackFormatted(locale: locale) }
            return Measurement(value: value, unit: volumeUnit)
                .formatted(.measurement(width: .abbreviated, usage: .general).locale(locale))
        case .count:
            let count = Int(value.rounded())
            switch unit {
            case .pack:
                return String(localized: "pantry.quantity.packs", defaultValue: "\(count) confezioni")
            default:
                return String(localized: "pantry.quantity.pieces", defaultValue: "\(count) pezzi")
            }
        }
    }

    private func fallbackFormatted(locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
}
