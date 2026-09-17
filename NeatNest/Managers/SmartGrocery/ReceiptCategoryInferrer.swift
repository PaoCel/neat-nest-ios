import Foundation

struct ReceiptCategoryInferrer {
    func inferCategory(
        rawLineText: String,
        matchedProduct: ProductCatalogItem?
    ) -> (category: GrocerySpendingCategory, confidence: Double) {
        if let matchedProduct, let category = category(for: matchedProduct) {
            return (category, 0.94)
        }

        let normalizedText = normalize(rawLineText)

        for rule in keywordRules {
            if rule.keywords.contains(where: normalizedText.contains) {
                return (rule.category, rule.confidence)
            }
        }

        return (.other, 0.42)
    }
}

private extension ReceiptCategoryInferrer {
    var keywordRules: [(keywords: [String], category: GrocerySpendingCategory, confidence: Double)] {
        [
            (["monopoly", "board game", "gioco", "lego", "carte"], .leisure, 0.9),
            (["detersivo", "pattumiera", "carta igienica", "sapone", "spugne"], .household, 0.82),
            (["acqua", "succo", "cola", "birra", "the"], .beverages, 0.78),
            (["pane", "focaccia", "grissini"], .bakery, 0.76),
            (["latte", "yogurt", "uova", "burro"], .dairy, 0.8),
            (["pasta", "riso", "tonno", "sugo"], .pantry, 0.78),
            (["pollo", "tacchino", "carne", "salmone"], .protein, 0.8),
            (["zucchine", "mele", "insalata", "pomodori", "frutta"], .produce, 0.78)
        ]
    }

    func category(for product: ProductCatalogItem) -> GrocerySpendingCategory? {
        switch normalize(product.category) {
        case "ortofrutta":
            return .produce
        case "freschi":
            return .dairy
        case "dispensa":
            return .pantry
        case "macelleria":
            return .protein
        case "panetteria":
            return .bakery
        case "bevande":
            return .beverages
        default:
            break
        }

        switch normalize(product.subcategory ?? "") {
        case "pollo":
            return .protein
        case "latte", "yogurt", "uova":
            return .dairy
        case "verdure":
            return .produce
        case "pane":
            return .bakery
        case "pasta", "riso", "conserve":
            return .pantry
        default:
            return nil
        }
    }

    func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
