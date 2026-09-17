import Foundation

/// Durata stimata di un prodotto, chiusa e dopo l'apertura.
struct ShelfLifeRule: Hashable, Sendable {
    let closedDays: Int
    let openedDays: Int

    static let unknown = ShelfLifeRule(closedDays: 0, openedDays: 0)

    var isUsable: Bool { closedDays > 0 }
}

/// Profilo di conservazione. Chiave stabile e indipendente dalla lingua: i token
/// che ci portano qui cambiano da lingua a lingua, il profilo no.
enum ShelfLifeProfile: String, CaseIterable, Sendable {
    case freshMilk
    case yogurt
    case cheese
    case eggs
    case freshMeat
    case freshFish
    case coldCuts
    case leafyGreens
    case sturdyVegetables
    case fruit
    case bread
    case pasta
    case cannedGoods
    case frozen
    case beverages
    case condiments
    case nonFood

    var rule: ShelfLifeRule {
        switch self {
        case .freshMilk:
            return ShelfLifeRule(closedDays: 7, openedDays: 3)
        case .yogurt:
            return ShelfLifeRule(closedDays: 21, openedDays: 2)
        case .cheese:
            return ShelfLifeRule(closedDays: 30, openedDays: 7)
        case .eggs:
            return ShelfLifeRule(closedDays: 28, openedDays: 28)
        case .freshMeat:
            return ShelfLifeRule(closedDays: 3, openedDays: 2)
        case .freshFish:
            return ShelfLifeRule(closedDays: 2, openedDays: 1)
        case .coldCuts:
            return ShelfLifeRule(closedDays: 14, openedDays: 4)
        case .leafyGreens:
            return ShelfLifeRule(closedDays: 5, openedDays: 3)
        case .sturdyVegetables:
            return ShelfLifeRule(closedDays: 14, openedDays: 7)
        case .fruit:
            return ShelfLifeRule(closedDays: 7, openedDays: 4)
        case .bread:
            return ShelfLifeRule(closedDays: 4, openedDays: 3)
        case .pasta:
            return ShelfLifeRule(closedDays: 540, openedDays: 90)
        case .cannedGoods:
            return ShelfLifeRule(closedDays: 730, openedDays: 2)
        case .frozen:
            return ShelfLifeRule(closedDays: 180, openedDays: 30)
        case .beverages:
            return ShelfLifeRule(closedDays: 365, openedDays: 5)
        case .condiments:
            return ShelfLifeRule(closedDays: 365, openedDays: 60)
        case .nonFood:
            return .unknown
        }
    }

    /// Profilo di ripiego quando il nome del prodotto non dice abbastanza.
    static func fallback(for category: GrocerySpendingCategory) -> ShelfLifeProfile {
        switch category {
        case .produce:
            return .fruit
        case .dairy:
            return .cheese
        case .protein:
            return .freshMeat
        case .bakery:
            return .bread
        case .beverages:
            return .beverages
        case .pantry:
            return .cannedGoods
        case .household, .leisure:
            return .nonFood
        case .other:
            return .cannedGoods
        }
    }
}

/// Deduce la shelf life dal nome del prodotto.
///
/// I token sono raggruppati per lingua: aggiungere l'inglese significa aggiungere
/// una voce a `tokensByLanguage`, non riscrivere la logica. Quando il nome non
/// contiene nulla di riconoscibile si ricade sulla categoria di spesa.
enum ShelfLifeCatalog {
    private static let tokensByLanguage: [String: [ShelfLifeProfile: [String]]] = [
        "it": [
            .freshMilk: ["latte", "panna"],
            .yogurt: ["yogurt", "skyr", "kefir"],
            .cheese: ["formaggio", "mozzarella", "parmigiano", "pecorino", "ricotta", "stracchino", "burro"],
            .eggs: ["uova", "uovo"],
            .freshMeat: ["pollo", "manzo", "maiale", "tacchino", "macinato", "salsiccia", "carne"],
            .freshFish: ["pesce", "salmone", "orata", "branzino", "gamberi", "tonno fresco"],
            .coldCuts: ["prosciutto", "salame", "mortadella", "bresaola", "speck", "affettat"],
            .leafyGreens: ["insalata", "spinaci", "rucola", "lattuga", "basilico", "valeriana"],
            .sturdyVegetables: ["patate", "carote", "cipolle", "zucchine", "melanzane", "peperoni", "pomodori", "aglio"],
            .fruit: ["mele", "banane", "arance", "pere", "fragole", "uva", "limoni", "frutta"],
            .bread: ["pane", "focaccia", "piadina", "brioche", "cornetti"],
            .pasta: ["pasta", "spaghetti", "rigatoni", "penne", "riso", "farina", "couscous"],
            .cannedGoods: ["tonno", "legumi", "fagioli", "ceci", "pelati", "passata", "mais", "conserva"],
            .frozen: ["surgelat", "congelat", "gelato"],
            .beverages: ["acqua", "succo", "birra", "vino", "bibita", "cola"],
            .condiments: ["olio", "aceto", "sale", "zucchero", "maionese", "ketchup", "senape", "spezie"],
            .nonFood: ["detersivo", "carta igienica", "sapone", "shampoo", "detergente"]
        ]
    ]

    static func profile(
        forProductNamed name: String,
        category: GrocerySpendingCategory,
        locale: Locale = .autoupdatingCurrent
    ) -> ShelfLifeProfile {
        let haystack = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)

        for language in LocalizedContent.candidateKeys(for: locale) {
            guard let tokens = tokensByLanguage[language] else { continue }

            for profile in ShelfLifeProfile.allCases {
                guard let candidates = tokens[profile] else { continue }
                if candidates.contains(where: { haystack.contains($0) }) {
                    return profile
                }
            }
        }

        return .fallback(for: category)
    }

    /// Data di scadenza stimata. `nil` per i non alimentari, dove una scadenza
    /// inventata sarebbe solo rumore.
    static func estimatedExpiry(
        productName: String,
        category: GrocerySpendingCategory,
        storage: PantryStorage,
        referenceDate: Date = Date(),
        openedAt: Date? = nil,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .current
    ) -> Date? {
        let profile = profile(forProductNamed: productName, category: category, locale: locale)
        let rule = profile.rule

        guard rule.isUsable else { return nil }

        if let openedAt {
            let days = max(1, Int((Double(rule.openedDays) * openedMultiplier(for: storage)).rounded()))
            return calendar.date(byAdding: .day, value: days, to: openedAt)
        }

        let days = max(1, Int((Double(rule.closedDays) * storage.shelfLifeMultiplier).rounded()))
        return calendar.date(byAdding: .day, value: days, to: referenceDate)
    }

    /// Il congelatore allunga la vita di un prodotto chiuso, ma una volta aperto
    /// e scongelato il vantaggio sparisce.
    private static func openedMultiplier(for storage: PantryStorage) -> Double {
        storage == .freezer ? 1 : storage.shelfLifeMultiplier
    }
}
