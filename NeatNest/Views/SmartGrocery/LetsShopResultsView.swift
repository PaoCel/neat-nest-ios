import SwiftUI

struct LetsShopResultsView: View {
    let recommendationSet: ShoppingRecommendationSet
    let list: UserGroceryList

    @State private var preferenceValue: Double

    init(recommendationSet: ShoppingRecommendationSet, list: UserGroceryList) {
        self.recommendationSet = recommendationSet
        self.list = list
        _preferenceValue = State(initialValue: recommendationSet.preferenceValue)
    }

    private var selectedKind: ShoppingRecommendationKind {
        ShoppingRecommendationKind.fromSliderValue(preferenceValue)
    }

    private var highlightedRecommendation: ShoppingRecommendation? {
        recommendationSet.recommendation(for: selectedKind)
    }

    private var convenienceTotal: Double {
        recommendationSet.recommendation(for: .convenience)?.estimatedTotal ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let highlightedRecommendation {
                    highlightedSection(highlightedRecommendation)
                }

                snapshotSection
                sliderRecapSection
                recommendationsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Piano spesa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func highlightedSection(_ recommendation: ShoppingRecommendation) -> some View {
        SmartGroceryHeroCard(colors: recommendation.kind.gradientColors) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("In primo piano")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(recommendation.kind.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(list.title)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(SmartGroceryFormatters.currency(recommendation.estimatedTotal))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        if recommendation.kind != .convenience,
                           convenienceTotal > recommendation.estimatedTotal {
                            SmartGroceryStatusBadge(
                                title: "-\(SmartGroceryFormatters.currency(convenienceTotal - recommendation.estimatedTotal))",
                                tint: .white
                            )
                        }
                    }
                }

                if let primaryRetailer = recommendation.primaryRetailer {
                    HStack(spacing: 8) {
                        SmartGroceryStatusBadge(title: primaryRetailer.name, tint: .white)
                        if let cityArea = primaryRetailer.cityArea {
                            SmartGroceryStatusBadge(title: cityArea, tint: .white)
                        }
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    CompactMetricTile(
                        title: "Store",
                        value: "\(recommendation.storeCount)",
                        tint: .white
                    )
                    CompactMetricTile(
                        title: "Coperti",
                        value: "\(recommendation.coveredItemCount)/\(recommendationSet.activeItemCount)",
                        tint: .white
                    )
                    CompactMetricTile(
                        title: "Da verificare",
                        value: "\(recommendation.missingCount)",
                        tint: .white
                    )
                }

                recommendationStoreStrip(recommendation)
            }
        }
    }

    private var snapshotSection: some View {
        SmartGrocerySurface(tint: .mint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Snapshot")
                        .font(.headline)

                    Spacer()

                    SmartGroceryStatusBadge(
                        title: SmartGroceryFormatters.relativeDate(recommendationSet.generatedAt),
                        tint: .primary
                    )
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                    spacing: 10
                ) {
                    CompactMetricTile(
                        title: "Articoli",
                        value: "\(recommendationSet.activeItemCount)",
                        tint: .green
                    )
                    CompactMetricTile(
                        title: "Prezzati",
                        value: "\(recommendationSet.pricedItemCount)",
                        tint: .blue
                    )
                    CompactMetricTile(
                        title: "Custom",
                        value: "\(recommendationSet.unresolvedCustomCount)",
                        tint: .orange
                    )
                    CompactMetricTile(
                        title: "Loyalty",
                        value: recommendationSet.loyaltyPricingApplied ? "On" : "Off",
                        tint: .primary
                    )
                }
            }
        }
    }

    private var sliderRecapSection: some View {
        SmartGrocerySurface(tint: selectedKind.tintColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Preferenza")
                        .font(.headline)

                    Spacer()

                    SmartGroceryStatusBadge(
                        title: "\(Int(preferenceValue.rounded())) • \(selectedKind.localizedTitle)",
                        tint: selectedKind.tintColor
                    )
                }

                Slider(value: $preferenceValue, in: 0...100, step: 1)
                    .tint(selectedKind.tintColor)

                HStack {
                    Text("Convenienza")
                    Spacer()
                    Text("Bilanciato")
                    Spacer()
                    Text("Risparmio")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Text(selectedKind.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Strategie")
                    .font(.title3.weight(.semibold))

                Spacer()

                SmartGroceryStatusBadge(
                    title: selectedKind.localizedTitle,
                    tint: selectedKind.tintColor
                )
            }

            ForEach(ShoppingRecommendationKind.allCases) { kind in
                if let recommendation = recommendationSet.recommendation(for: kind) {
                    RecommendationCard(
                        recommendation: recommendation,
                        isHighlighted: kind == selectedKind,
                        convenienceTotal: convenienceTotal
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func recommendationStoreStrip(_ recommendation: ShoppingRecommendation) -> some View {
        let displayedBreakdowns = Array(recommendation.storeBreakdowns.prefix(3))

        if !displayedBreakdowns.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedBreakdowns) { breakdown in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(breakdown.retailer.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)

                            Text(SmartGroceryFormatters.currency(breakdown.subtotal))
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                        )
                    }
                }
            }
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: ShoppingRecommendation
    let isHighlighted: Bool
    let convenienceTotal: Double

    @State private var isExpanded = false

    private var detailToggleTitle: String {
        isExpanded ? "Nascondi dettagli" : "Apri dettagli"
    }

    var body: some View {
        SmartGrocerySurface(tint: recommendation.kind.tintColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(recommendation.title)
                                .font(.title3.weight(.semibold))

                            if isHighlighted {
                                SmartGroceryStatusBadge(title: "Scelta", tint: recommendation.kind.tintColor)
                            }
                        }

                        if let primaryRetailer = recommendation.primaryRetailer {
                            Text(primaryRetailerLabel(primaryRetailer))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(SmartGroceryFormatters.currency(recommendation.estimatedTotal))
                            .font(.title3.weight(.bold))

                        if recommendation.kind != .convenience && convenienceTotal > recommendation.estimatedTotal {
                            SmartGroceryStatusBadge(
                                title: "-\(SmartGroceryFormatters.currency(convenienceTotal - recommendation.estimatedTotal))",
                                tint: .green
                            )
                        }
                    }
                }

                if !recommendation.summary.isEmpty {
                    Text(recommendation.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? 3 : 2)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    CompactMetricTile(
                        title: "Store",
                        value: "\(recommendation.storeCount)",
                        tint: recommendation.kind.tintColor
                    )
                    CompactMetricTile(
                        title: "Coperti",
                        value: "\(recommendation.coveredItemCount)/\(recommendation.totalConsideredItems)",
                        tint: .green
                    )
                    CompactMetricTile(
                        title: recommendation.missingCount == 0 ? "Confidenza" : "Verifica",
                        value: recommendation.missingCount == 0
                            ? SmartGroceryFormatters.percentLabel(recommendation.overallConfidence)
                            : "\(recommendation.missingCount)",
                        tint: recommendation.missingCount == 0 ? .primary : .orange
                    )
                }

                if !recommendation.storeBreakdowns.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(recommendation.storeBreakdowns) { breakdown in
                            StoreBreakdownView(
                                breakdown: breakdown,
                                showAssignments: isExpanded
                            )
                        }
                    }
                }

                if recommendation.missingCount > 0 {
                    MissingItemsSummaryView(
                        items: recommendation.missingPricedItems + recommendation.unresolvedItems,
                        showAll: isExpanded
                    )
                }

                HStack(spacing: 10) {
                    if let freshestUpdate = recommendation.freshestUpdate {
                        SmartGroceryStatusBadge(
                            title: "Agg. \(SmartGroceryFormatters.relativeDate(freshestUpdate))",
                            tint: .primary
                        )
                    }

                    Spacer()

                    Button(detailToggleTitle) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(recommendation.kind.tintColor)
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    isHighlighted ? recommendation.kind.tintColor.opacity(0.45) : Color.clear,
                    lineWidth: 2
                )
        )
    }

    private func primaryRetailerLabel(_ retailer: Retailer) -> String {
        if let cityArea = retailer.cityArea, !cityArea.isEmpty {
            return "\(retailer.name) • \(cityArea)"
        }

        return retailer.name
    }
}

private struct StoreBreakdownView: View {
    let breakdown: ShoppingStoreBreakdown
    let showAssignments: Bool

    private var previewAssignments: [ShoppingBasketAssignment] {
        Array(breakdown.assignments.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakdown.retailer.name)
                        .font(.headline)

                    if let cityArea = breakdown.retailer.cityArea {
                        Text(cityArea)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(SmartGroceryFormatters.currency(breakdown.subtotal))
                        .font(.headline.weight(.bold))

                    Text("\(breakdown.assignments.count) articoli")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(previewAssignments) { assignment in
                        AssignmentPreviewPill(assignment: assignment)
                    }

                    if breakdown.assignments.count > previewAssignments.count {
                        SmartGroceryStatusBadge(
                            title: "+\(breakdown.assignments.count - previewAssignments.count)",
                            tint: .primary
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                SmartGroceryStatusBadge(
                    title: SmartGroceryFormatters.percentLabel(breakdown.averageConfidence),
                    tint: .primary
                )

                if let latestPriceUpdate = breakdown.latestPriceUpdate {
                    SmartGroceryStatusBadge(
                        title: SmartGroceryFormatters.relativeDate(latestPriceUpdate),
                        tint: .primary
                    )
                }
            }

            if showAssignments {
                VStack(spacing: 10) {
                    ForEach(breakdown.assignments) { assignment in
                        BasketAssignmentRow(assignment: assignment)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

private struct BasketAssignmentRow: View {
    let assignment: ShoppingBasketAssignment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.18))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(assignment.item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let pricingBadge = assignment.pricingBadge {
                        SmartGroceryStatusBadge(
                            title: pricingBadge,
                            tint: pricingBadge == "Loyalty" ? .blue : .orange
                        )
                    }
                }

                Text(
                    "\(SmartGroceryFormatters.quantityLabel(quantity: assignment.item.quantity, unit: assignment.item.unit)) • \(SmartGroceryFormatters.currency(assignment.unitPrice, currencyCode: assignment.retailerPrice.currency))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(SmartGroceryFormatters.currency(assignment.estimatedTotal, currencyCode: assignment.retailerPrice.currency))
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct MissingItemsSummaryView: View {
    let items: [ShoppingRecommendationMissingItem]
    let showAll: Bool

    private var visibleItems: [ShoppingRecommendationMissingItem] {
        Array(items.prefix(showAll ? items.count : 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Da verificare", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Spacer()

                SmartGroceryStatusBadge(title: "\(items.count)", tint: .orange)
            }

            ForEach(visibleItems) { item in
                MissingRecommendationItemRow(item: item)
            }

            if items.count > visibleItems.count {
                Text("+\(items.count - visibleItems.count) altre voci")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MissingRecommendationItemRow: View {
    let item: ShoppingRecommendationMissingItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(item.displayReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct CompactMetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.95))
        )
    }
}

private struct AssignmentPreviewPill: View {
    let assignment: ShoppingBasketAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.item.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text(SmartGroceryFormatters.currency(assignment.estimatedTotal, currencyCode: assignment.retailerPrice.currency))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }
}

#Preview("Let's Shop Results") {
    NavigationStack {
        LetsShopResultsView(
            recommendationSet: PreviewSupport.recommendationSet,
            list: PreviewSupport.defaultList
        )
    }
}
