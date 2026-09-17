import Foundation

struct ShoppingRecommendationEngine {
    func buildRecommendations(
        for list: UserGroceryList,
        activeItems: [UserGroceryListItem],
        catalog: [ProductCatalogItem],
        retailers: [Retailer],
        prices: [RetailerProductPrice],
        preferenceValue: Double,
        considerLoyaltyPricing: Bool
    ) -> ShoppingRecommendationSet {
        let activeRetailers = retailers.filter(\.isActive)
        let catalogById = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        let retailerById = Dictionary(uniqueKeysWithValues: activeRetailers.map { ($0.id, $0) })
        let availablePricesByProductId = Dictionary(
            grouping: prices.filter { $0.isAvailable && retailerById[$0.retailerId] != nil },
            by: \.productCatalogId
        )

        let analysis = analyzeItems(
            activeItems,
            catalogById: catalogById,
            retailerById: retailerById,
            pricesByProductId: availablePricesByProductId,
            considerLoyaltyPricing: considerLoyaltyPricing
        )

        let convenience = buildConvenienceRecommendation(
            candidates: analysis.candidates,
            retailers: activeRetailers,
            unresolvedItems: analysis.unresolvedItems
        )

        let balanced = buildBalancedRecommendation(
            candidates: analysis.candidates,
            retailers: activeRetailers,
            unresolvedItems: analysis.unresolvedItems,
            fallbackRetailerId: convenience.primaryRetailer?.id
        )

        let savings = buildSavingsRecommendation(
            candidates: analysis.candidates,
            unresolvedItems: analysis.unresolvedItems
        )

        let recommendations = [convenience, balanced, savings]
        let highlightedKind = ShoppingRecommendationKind.fromSliderValue(preferenceValue)

        return ShoppingRecommendationSet(
            id: "\(list.id)-\(Int(Date().timeIntervalSince1970))",
            list: list,
            generatedAt: Date(),
            preferenceValue: preferenceValue,
            highlightedKind: highlightedKind,
            recommendations: recommendations,
            activeItemCount: activeItems.count,
            pricedItemCount: analysis.candidates.count,
            unresolvedCustomCount: analysis.unresolvedItems.count,
            loyaltyPricingApplied: considerLoyaltyPricing
        )
    }
}

private extension ShoppingRecommendationEngine {
    struct Candidate {
        let item: UserGroceryListItem
        let product: ProductCatalogItem
        let options: [PriceOption]

        func option(for retailerId: String) -> PriceOption? {
            options.first(where: { $0.retailer.id == retailerId })
        }
    }

    struct PriceOption {
        let retailer: Retailer
        let price: RetailerProductPrice
        let unitPrice: Double
        let totalPrice: Double
        let pricingBadge: String?
    }

    struct AnalysisResult {
        let candidates: [Candidate]
        let unresolvedItems: [ShoppingRecommendationMissingItem]
    }

    func analyzeItems(
        _ items: [UserGroceryListItem],
        catalogById: [String: ProductCatalogItem],
        retailerById: [String: Retailer],
        pricesByProductId: [String: [RetailerProductPrice]],
        considerLoyaltyPricing: Bool
    ) -> AnalysisResult {
        var candidates: [Candidate] = []
        var unresolvedItems: [ShoppingRecommendationMissingItem] = []

        for item in items {
            guard let productCatalogId = item.productCatalogId,
                  let product = catalogById[productCatalogId] else {
                unresolvedItems.append(
                    ShoppingRecommendationMissingItem(
                        item: item,
                        matchedProductName: item.normalizedName,
                        displayReason: "Voce custom: serve una verifica manuale prima di assegnare il supermercato."
                    )
                )
                continue
            }

            let options = (pricesByProductId[productCatalogId] ?? [])
                .compactMap { price -> PriceOption? in
                    guard let retailer = retailerById[price.retailerId] else {
                        return nil
                    }

                    let unitPrice = price.effectivePrice(considerLoyaltyPricing: considerLoyaltyPricing)
                    return PriceOption(
                        retailer: retailer,
                        price: price,
                        unitPrice: unitPrice,
                        totalPrice: unitPrice * item.quantity,
                        pricingBadge: price.pricingBadge(considerLoyaltyPricing: considerLoyaltyPricing)
                    )
                }
                .sorted {
                    if abs($0.totalPrice - $1.totalPrice) > 0.0001 {
                        return $0.totalPrice < $1.totalPrice
                    }

                    return $0.retailer.name.localizedCaseInsensitiveCompare($1.retailer.name) == .orderedAscending
                }

            candidates.append(
                Candidate(
                    item: item,
                    product: product,
                    options: options
                )
            )
        }

        return AnalysisResult(candidates: candidates, unresolvedItems: unresolvedItems)
    }

    func buildConvenienceRecommendation(
        candidates: [Candidate],
        retailers: [Retailer],
        unresolvedItems: [ShoppingRecommendationMissingItem]
    ) -> ShoppingRecommendation {
        let bestRetailer = retailers.min { lhs, rhs in
            let lhsScore = singleStoreScore(for: lhs.id, candidates: candidates)
            let rhsScore = singleStoreScore(for: rhs.id, candidates: candidates)

            if abs(lhsScore.score - rhsScore.score) > 0.0001 {
                return lhsScore.score < rhsScore.score
            }

            if lhsScore.coveredCount != rhsScore.coveredCount {
                return lhsScore.coveredCount > rhsScore.coveredCount
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        guard let bestRetailer else {
            return emptyRecommendation(
                kind: .convenience,
                unresolvedItems: unresolvedItems,
                totalItems: candidates.count + unresolvedItems.count
            )
        }

        let assignments = candidates.compactMap { assignment(for: $0, retailerId: bestRetailer.id) }
        let missingItems = candidates
            .filter { assignment(for: $0, retailerId: bestRetailer.id) == nil }
            .map {
                ShoppingRecommendationMissingItem(
                    item: $0.item,
                    matchedProductName: $0.product.canonicalName,
                    displayReason: "Non disponibile da \(bestRetailer.name)."
                )
            }

        return buildRecommendation(
            kind: .convenience,
            summary: "Un unico punto vendita, pensato per chi vuole chiudere la spesa in modo lineare.",
            assignments: assignments,
            missingItems: missingItems,
            unresolvedItems: unresolvedItems,
            totalItems: candidates.count + unresolvedItems.count
        )
    }

    func buildBalancedRecommendation(
        candidates: [Candidate],
        retailers: [Retailer],
        unresolvedItems: [ShoppingRecommendationMissingItem],
        fallbackRetailerId: String?
    ) -> ShoppingRecommendation {
        let primaryRetailerId = fallbackRetailerId ?? retailers.min { lhs, rhs in
            singleStoreScore(for: lhs.id, candidates: candidates).score < singleStoreScore(for: rhs.id, candidates: candidates).score
        }?.id

        guard let primaryRetailerId else {
            return emptyRecommendation(
                kind: .balanced,
                unresolvedItems: unresolvedItems,
                totalItems: candidates.count + unresolvedItems.count
            )
        }

        let switchCandidates = candidates.compactMap { candidate -> (retailerId: String, savings: Double, fixesMissing: Bool)? in
            let primaryOption = candidate.option(for: primaryRetailerId)
            let bestOption = candidate.options.first

            if primaryOption == nil, let bestOption {
                return (bestOption.retailer.id, 0, true)
            }

            guard let primaryOption,
                  let bestOption,
                  bestOption.retailer.id != primaryRetailerId else {
                return nil
            }

            let savings = primaryOption.totalPrice - bestOption.totalPrice
            let savingsThreshold = max(0.45, primaryOption.totalPrice * 0.14)

            guard savings >= savingsThreshold else {
                return nil
            }

            return (bestOption.retailer.id, savings, false)
        }

        let groupedSwitches = Dictionary(grouping: switchCandidates, by: \.retailerId)
        let secondaryRetailerId = groupedSwitches.max { lhs, rhs in
            switchGroupScore(lhs.value) < switchGroupScore(rhs.value)
        }?.key

        let shouldUseSecondary = secondaryRetailerId.flatMap { retailerId -> Bool? in
            let switches = groupedSwitches[retailerId] ?? []
            let totalSavings = switches.reduce(0) { $0 + $1.savings }
            let fixedCoverage = switches.filter(\.fixesMissing).count
            return totalSavings >= 1.25 || fixedCoverage > 0
        } ?? false

        let assignments = candidates.compactMap { candidate -> ShoppingBasketAssignment? in
            if let secondaryRetailerId, shouldUseSecondary {
                let primaryOption = candidate.option(for: primaryRetailerId)
                let secondaryOption = candidate.option(for: secondaryRetailerId)

                if primaryOption == nil, let secondaryOption {
                    return makeAssignment(candidate: candidate, option: secondaryOption)
                }

                if let primaryOption, let secondaryOption {
                    let savings = primaryOption.totalPrice - secondaryOption.totalPrice
                    let savingsThreshold = max(0.45, primaryOption.totalPrice * 0.14)

                    if savings >= savingsThreshold {
                        return makeAssignment(candidate: candidate, option: secondaryOption)
                    }
                }
            }

            if let primaryOption = candidate.option(for: primaryRetailerId) {
                return makeAssignment(candidate: candidate, option: primaryOption)
            }

            return nil
        }

        let assignedItemIds = Set(assignments.map(\.item.id))
        let missingItems = candidates
            .filter { !assignedItemIds.contains($0.item.id) }
            .map {
                ShoppingRecommendationMissingItem(
                    item: $0.item,
                    matchedProductName: $0.product.canonicalName,
                    displayReason: "Nessun prezzo affidabile nel piano bilanciato."
                )
            }

        return buildRecommendation(
            kind: .balanced,
            summary: "Tiene il focus su uno store principale e apre un secondo passaggio solo quando il guadagno e concreto.",
            assignments: assignments,
            missingItems: missingItems,
            unresolvedItems: unresolvedItems,
            totalItems: candidates.count + unresolvedItems.count
        )
    }

    func buildSavingsRecommendation(
        candidates: [Candidate],
        unresolvedItems: [ShoppingRecommendationMissingItem]
    ) -> ShoppingRecommendation {
        var preferredRetailerIds: Set<String> = []

        let assignments = candidates.compactMap { candidate -> ShoppingBasketAssignment? in
            let choice = candidate.options.min { lhs, rhs in
                if abs(lhs.totalPrice - rhs.totalPrice) <= 0.05 {
                    let lhsPreferred = preferredRetailerIds.contains(lhs.retailer.id)
                    let rhsPreferred = preferredRetailerIds.contains(rhs.retailer.id)

                    if lhsPreferred != rhsPreferred {
                        return lhsPreferred && !rhsPreferred
                    }
                }

                if abs(lhs.totalPrice - rhs.totalPrice) > 0.0001 {
                    return lhs.totalPrice < rhs.totalPrice
                }

                return lhs.retailer.name.localizedCaseInsensitiveCompare(rhs.retailer.name) == .orderedAscending
            }

            guard let choice else {
                return nil
            }

            preferredRetailerIds.insert(choice.retailer.id)
            return makeAssignment(candidate: candidate, option: choice)
        }

        let assignedItemIds = Set(assignments.map(\.item.id))
        let missingItems = candidates
            .filter { !assignedItemIds.contains($0.item.id) }
            .map {
                ShoppingRecommendationMissingItem(
                    item: $0.item,
                    matchedProductName: $0.product.canonicalName,
                    displayReason: "Non ci sono prezzi disponibili per questo articolo."
                )
            }

        return buildRecommendation(
            kind: .savings,
            summary: "Scompone il carrello dove serve per abbassare al massimo il totale stimato.",
            assignments: assignments,
            missingItems: missingItems,
            unresolvedItems: unresolvedItems,
            totalItems: candidates.count + unresolvedItems.count
        )
    }

    func singleStoreScore(for retailerId: String, candidates: [Candidate]) -> (score: Double, coveredCount: Int) {
        var subtotal = 0.0
        var coveredCount = 0
        var missingCount = 0

        for candidate in candidates {
            if let option = candidate.option(for: retailerId) {
                subtotal += option.totalPrice
                coveredCount += 1
            } else {
                missingCount += 1
            }
        }

        return (subtotal + Double(missingCount) * 7.5, coveredCount)
    }

    func switchGroupScore(_ switches: [(retailerId: String, savings: Double, fixesMissing: Bool)]) -> Double {
        let totalSavings = switches.reduce(0) { $0 + $1.savings }
        let fixedCoverage = Double(switches.filter(\.fixesMissing).count) * 2.0
        return totalSavings + fixedCoverage
    }

    func assignment(for candidate: Candidate, retailerId: String) -> ShoppingBasketAssignment? {
        guard let option = candidate.option(for: retailerId) else {
            return nil
        }

        return makeAssignment(candidate: candidate, option: option)
    }

    func makeAssignment(candidate: Candidate, option: PriceOption) -> ShoppingBasketAssignment {
        ShoppingBasketAssignment(
            item: candidate.item,
            catalogItem: candidate.product,
            retailer: option.retailer,
            retailerPrice: option.price,
            unitPrice: option.unitPrice,
            estimatedTotal: option.totalPrice,
            pricingBadge: option.pricingBadge
        )
    }

    func buildRecommendation(
        kind: ShoppingRecommendationKind,
        summary: String,
        assignments: [ShoppingBasketAssignment],
        missingItems: [ShoppingRecommendationMissingItem],
        unresolvedItems: [ShoppingRecommendationMissingItem],
        totalItems: Int
    ) -> ShoppingRecommendation {
        let groupedAssignments = Dictionary(grouping: assignments, by: { $0.retailer.id })
        let storeBreakdowns = groupedAssignments.compactMap { _, items -> ShoppingStoreBreakdown? in
            guard let retailer = items.first?.retailer else {
                return nil
            }

            let subtotal = items.reduce(0) { $0 + $1.estimatedTotal }
            let averageConfidence = items.isEmpty ? 0 : items.reduce(0) { $0 + $1.retailerPrice.sourceConfidence } / Double(items.count)
            let latestPriceUpdate = items.map(\.retailerPrice.lastUpdatedAt).max()

            return ShoppingStoreBreakdown(
                retailer: retailer,
                assignments: items.sorted { lhs, rhs in
                    lhs.item.displayName.localizedCaseInsensitiveCompare(rhs.item.displayName) == .orderedAscending
                },
                subtotal: subtotal,
                averageConfidence: averageConfidence,
                latestPriceUpdate: latestPriceUpdate
            )
        }
        .sorted { lhs, rhs in
            if lhs.assignments.count != rhs.assignments.count {
                return lhs.assignments.count > rhs.assignments.count
            }

            if abs(lhs.subtotal - rhs.subtotal) > 0.0001 {
                return lhs.subtotal > rhs.subtotal
            }

            return lhs.retailer.name.localizedCaseInsensitiveCompare(rhs.retailer.name) == .orderedAscending
        }

        let allPrices = assignments.map(\.retailerPrice)
        let confidence = allPrices.isEmpty ? 0 : allPrices.reduce(0) { $0 + $1.sourceConfidence } / Double(allPrices.count)

        return ShoppingRecommendation(
            kind: kind,
            title: kind.localizedTitle,
            summary: summary,
            storeBreakdowns: storeBreakdowns,
            estimatedTotal: assignments.reduce(0) { $0 + $1.estimatedTotal },
            totalConsideredItems: totalItems,
            missingPricedItems: missingItems,
            unresolvedItems: unresolvedItems,
            overallConfidence: confidence,
            freshestUpdate: allPrices.map(\.lastUpdatedAt).max(),
            stalestUpdate: allPrices.map(\.lastUpdatedAt).min()
        )
    }

    func emptyRecommendation(
        kind: ShoppingRecommendationKind,
        unresolvedItems: [ShoppingRecommendationMissingItem],
        totalItems: Int
    ) -> ShoppingRecommendation {
        ShoppingRecommendation(
            kind: kind,
            title: kind.localizedTitle,
            summary: kind.subtitle,
            storeBreakdowns: [],
            estimatedTotal: 0,
            totalConsideredItems: totalItems,
            missingPricedItems: [],
            unresolvedItems: unresolvedItems,
            overallConfidence: 0,
            freshestUpdate: nil,
            stalestUpdate: nil
        )
    }
}
