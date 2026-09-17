import SwiftUI

struct PriceCompareView: View {
    let item: UserGroceryListItem
    let catalog: ProductCatalogItem?
    let prices: [RetailerProductPrice]
    let retailers: [Retailer]
    let considerLoyaltyPricing: Bool


    private var retailerById: [String: Retailer] {
        Dictionary(uniqueKeysWithValues: retailers.map { ($0.id, $0) })
    }

    private var sortedPrices: [(price: RetailerProductPrice, retailer: Retailer)] {
        prices
            .filter { $0.productCatalogId == item.productCatalogId && $0.isAvailable }
            .compactMap { price in
                guard let retailer = retailerById[price.retailerId] else { return nil }
                return (price: price, retailer: retailer)
            }
            .sorted { lhs, rhs in
                lhs.price.effectivePrice(considerLoyaltyPricing: considerLoyaltyPricing)
                < rhs.price.effectivePrice(considerLoyaltyPricing: considerLoyaltyPricing)
            }
    }

    private var maxPrice: Double {
        sortedPrices.map { $0.price.basePrice }.max() ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                productHeader
                priceChart
                priceDetails
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemGray6), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Confronto prezzi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var productHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.displayName)
                .font(.title2.weight(.bold))

            if let catalog {
                HStack(spacing: 8) {
                    if let brand = catalog.brand {
                        Text(brand)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let size = catalog.sizeLabel {
                        Text(size)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                    }
                    Text(catalog.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GS1ConfidenceBadge(confidence: item.catalogEnrichmentConfidence)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var priceChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prezzi nei supermercati")
                .font(.headline)

            if sortedPrices.isEmpty {
                SmartGroceryEmptyState(
                    icon: "tag.slash",
                    title: "Nessun prezzo disponibile",
                    subtitle: "Non abbiamo trovato prezzi per questo prodotto."
                )
            } else {
                ForEach(Array(sortedPrices.enumerated()), id: \.offset) { index, entry in
                    PriceBarRow(
                        retailerName: entry.retailer.displayName,
                        effectivePrice: entry.price.effectivePrice(considerLoyaltyPricing: considerLoyaltyPricing),
                        basePrice: entry.price.basePrice,
                        maxPrice: maxPrice,
                        badge: entry.price.pricingBadge(considerLoyaltyPricing: considerLoyaltyPricing),
                        isCheapest: index == 0
                    )
                }
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var priceDetails: some View {
        if !sortedPrices.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dettaglio per supermercato")
                    .font(.headline)

                ForEach(Array(sortedPrices.enumerated()), id: \.offset) { _, entry in
                    PriceDetailRow(price: entry.price, retailer: entry.retailer)
                }
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Price Bar Row

private struct PriceBarRow: View {
    let retailerName: String
    let effectivePrice: Double
    let basePrice: Double
    let maxPrice: Double
    let badge: String?
    let isCheapest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(retailerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(effectivePrice, format: .euro)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isCheapest ? .green : .primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isCheapest ? Color.green : Color.orange.opacity(0.7))
                        .frame(width: max(0, geo.size.width * (effectivePrice / maxPrice)), height: 12)
                }
            }
            .frame(height: 12)

            HStack(spacing: 6) {
                if let badge {
                    PriceBadge(
                        text: badge,
                        color: badge == "Loyalty" ? .purple : .orange
                    )
                }

                if effectivePrice < basePrice {
                    Text("Prezzo pieno: \(basePrice, format: .euro)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if isCheapest {
                    Text("Miglior prezzo")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Price Detail Row

private struct PriceDetailRow: View {
    let price: RetailerProductPrice
    let retailer: Retailer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(retailer.name)
                    .font(.subheadline.weight(.semibold))
                if let area = retailer.cityArea {
                    Text(area)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                PriceLabel(title: "Scaffale", price: price.basePrice)

                if let promo = price.promoPrice {
                    PriceLabel(title: "Promo", price: promo, color: .orange)
                }

                if let loyalty = price.loyaltyPrice {
                    PriceLabel(title: "Fidelity", price: loyalty, color: .purple)
                }
            }

            if let discount = price.discountPercentage {
                Text("-\(String(format: "%.0f", discount))% rispetto al prezzo pieno")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Aggiornato: \(price.lastUpdatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PriceLabel: View {
    let title: String
    let price: Double
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(price, format: .euro)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
    }
}

private extension RetailerProductPrice {
    var discountPercentage: Double? {
        guard let promo = promoPrice, promo < basePrice, basePrice > 0 else { return nil }
        return ((basePrice - promo) / basePrice) * 100
    }
}
