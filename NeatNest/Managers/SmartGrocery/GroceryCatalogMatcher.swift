import Foundation

struct GroceryCatalogMatcher {
    private let stopwords: Set<String> = [
        "a", "ai", "al", "alla", "alle", "allo", "con", "da", "dei", "degli",
        "dei", "del", "della", "delle", "di", "gli", "i", "il", "in", "la",
        "le", "lo", "un", "una", "uno"
    ]

    func bestMatch(for rawInput: String, within catalog: [ProductCatalogItem]) -> GroceryCatalogMatch? {
        let normalizedInput = normalize(rawInput)
        guard !normalizedInput.isEmpty else { return nil }

        let inputTokens = Set(tokenize(normalizedInput))
        var bestCandidate: GroceryCatalogMatch?

        for product in catalog where product.isActive {
            let candidates = [product.canonicalName] + product.aliases

            for candidate in candidates {
                let normalizedCandidate = normalize(candidate)
                let candidateTokens = Set(tokenize(normalizedCandidate))

                guard !candidateTokens.isEmpty else { continue }

                let exactMatch = normalizedInput == normalizedCandidate
                let fullTokenContainment = candidateTokens.isSubset(of: inputTokens)
                let overlap = candidateTokens.intersection(inputTokens).count
                let searchableTokenBonus = product.searchableTokens
                    .map(normalize(_:))
                    .filter { !$0.isEmpty }
                    .contains(normalizedInput)

                guard exactMatch || fullTokenContainment || overlap >= min(2, candidateTokens.count) else {
                    continue
                }

                var score = 0
                if exactMatch {
                    score += 1000
                }
                if fullTokenContainment {
                    score += 200
                }

                score += overlap * 40
                score += searchableTokenBonus ? 60 : 0
                score -= abs(normalizedInput.count - normalizedCandidate.count)

                let match = GroceryCatalogMatch(product: product, source: candidate, score: score)
                if bestCandidate == nil || match.score > bestCandidate?.score ?? .min {
                    bestCandidate = match
                }
            }
        }

        guard let bestCandidate, bestCandidate.score >= 80 else {
            return nil
        }

        return bestCandidate
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                !token.isEmpty && !stopwords.contains(token)
            }
    }
}
