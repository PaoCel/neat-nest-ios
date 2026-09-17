import SwiftUI

enum SmartGroceryFormatters {
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func quantityLabel(quantity: Double, unit: String?) -> String {
        let number = quantityFormatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
        if let unit, !unit.isEmpty {
            return "\(number) \(unit)"
        }
        return number
    }

    static func currency(_ amount: Double, currencyCode: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    static func percentLabel(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return percentFormatter.string(from: NSNumber(value: clampedValue)) ?? "\(Int(clampedValue * 100))%"
    }
}

struct SmartGrocerySurface<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = Color.green, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

struct SmartGroceryHeroCard<Content: View>: View {
    let colors: [Color]
    let content: Content

    init(colors: [Color], @ViewBuilder content: () -> Content) {
        self.colors = colors
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: colors.first?.opacity(0.22) ?? Color.clear, radius: 18, x: 0, y: 10)
    }
}

struct SmartGrocerySectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)
            trailing
        }
    }
}

struct SmartGroceryStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(badgeBackgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(badgeStrokeColor, lineWidth: 1)
            )
    }

    private var badgeBackgroundColor: Color {
        if tint == .white {
            return Color.white.opacity(0.18)
        }

        return tint.opacity(0.12)
    }

    private var badgeStrokeColor: Color {
        if tint == .white {
            return Color.white.opacity(0.28)
        }

        return tint.opacity(0.16)
    }
}

struct SmartGroceryEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        SmartGrocerySurface(tint: .gray) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.green)

                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SmartGroceryComingSoonCard: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        SmartGrocerySurface(tint: .orange) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SmartGroceryStatusBadge(title: "Presto disponibile", tint: .orange)
                }
            }
        }
    }
}

struct SmartGroceryListPreviewCard: View {
    let summary: GroceryListSummary

    var body: some View {
        SmartGrocerySurface(tint: summary.list.isDefault ? .green : .mint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.list.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text("Aggiornata \(SmartGroceryFormatters.relativeDate(summary.list.updatedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    if summary.list.isDefault {
                        SmartGroceryStatusBadge(title: "Principale", tint: .green)
                    }
                }

                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    SmartGroceryStatusBadge(title: "\(summary.activeCount) da comprare", tint: .green)
                    if summary.purchasedCount > 0 {
                        SmartGroceryStatusBadge(title: "\(summary.purchasedCount) acquistati", tint: .blue)
                    } else {
                        SmartGroceryStatusBadge(title: "Lista aperta", tint: .primary)
                    }
                }
            }
        }
    }

    private var summaryLine: String {
        if summary.itemCount == 0 {
            return "Lista vuota, pronta da compilare."
        }

        if summary.purchasedCount == 0 {
            return "\(summary.itemCount) articoli in lista."
        }

        return "\(summary.itemCount) articoli totali, di cui \(summary.purchasedCount) gia segnati."
    }
}

struct SmartGroceryRecentItemRow: View {
    let item: UserGroceryListItem
    let listTitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.status == .purchased ? "checkmark.circle.fill" : "circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(item.status == .purchased ? .blue : .green)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    SmartGroceryStatusBadge(
                        title: item.effectiveEnrichmentStatus.localizedTitle,
                        tint: item.effectiveEnrichmentStatus.tintColor
                    )
                    SmartGroceryStatusBadge(
                        title: SmartGroceryFormatters.quantityLabel(quantity: item.quantity, unit: item.unit),
                        tint: Color.primary
                    )
                }

                if item.effectiveEnrichmentStatus.isPending {
                    Text("Sto cercando un prodotto reale da collegare al catalogo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let listTitle {
                    Text(listTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(SmartGroceryFormatters.relativeDate(item.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SmartGrocerySuggestionChip: View {
    let item: ProductCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Da ricomprare")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            Text(item.canonicalName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(item.category)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let sizeLabel = item.sizeLabel {
                Text(sizeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.green.opacity(0.14), lineWidth: 1)
        )
    }
}

struct SmartGroceryMatchPreviewCard: View {
    let rawInputText: String
    let match: GroceryCatalogMatch?

    var body: some View {
        SmartGrocerySurface(tint: match == nil ? .gray : .green) {
            if rawInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match catalogo")
                        .font(.headline)
                    Text("Inserisci un articolo per vedere come verra normalizzato e collegato al catalogo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let match {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Match catalogo")
                            .font(.headline)
                        Spacer()
                        SmartGroceryStatusBadge(title: "Risolto", tint: .green)
                    }

                    Text(match.product.canonicalName)
                        .font(.title3.weight(.semibold))

                    HStack(spacing: 10) {
                        Text(match.product.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let brand = match.product.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Riconosciuto da: \(match.source)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Match catalogo")
                            .font(.headline)
                        Spacer()
                        SmartGroceryStatusBadge(title: "Custom", tint: .gray)
                    }

                    Text("Nessun match preciso trovato per ora.")
                        .font(.subheadline.weight(.semibold))

                    Text("L'articolo verra salvato subito e NeatNest provera a cercare un prodotto reale in background.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension ShoppingRecommendationKind {
    var tintColor: Color {
        switch self {
        case .convenience:
            return .blue
        case .balanced:
            return .green
        case .savings:
            return .orange
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .convenience:
            return [Color.blue, Color.cyan]
        case .balanced:
            return [Color.green, Color.mint]
        case .savings:
            return [Color.orange, Color.red]
        }
    }
}

extension GroceryCatalogEnrichmentStatus {
    var tintColor: Color {
        switch self {
        case .queued, .searching:
            return .orange
        case .resolved:
            return .green
        case .unresolved:
            return .gray
        }
    }
}

@MainActor
private struct SmartGroceryComponentsPreviewContainer: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SmartGroceryHeroCard(colors: [.green, .mint]) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Smart Grocery UI kit")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Preview rapida dei componenti base per ritoccare il design senza fare una build completa.")
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }

                SmartGrocerySurface(tint: .green) {
                    SmartGrocerySectionHeader(
                        title: "Componenti base",
                        subtitle: "Card, badge e righe principali."
                    ) {
                        SmartGroceryStatusBadge(title: "Preview", tint: .green)
                    }

                    SmartGroceryListPreviewCard(summary: PreviewSupport.listSummaries[0])
                    SmartGroceryRecentItemRow(item: PreviewSupport.activeItems[0], listTitle: PreviewSupport.defaultList.title)
                    SmartGrocerySuggestionChip(item: PreviewSupport.upcomingSuggestions[0])
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#Preview("Smart Grocery Components") {
    SmartGroceryComponentsPreviewContainer()
}

// MARK: - GS1 Confidence Badge (Price Compare)

struct GS1ConfidenceBadge: View {
    let confidence: Double?

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var emoji: String {
        guard let confidence else { return "🔴" }
        if confidence >= 0.9 { return "🟢" }
        if confidence >= 0.6 { return "🟡" }
        return "🔴"
    }

    private var label: String {
        guard let confidence else { return "Non verificato" }
        if confidence >= 0.9 { return "Match sicuro" }
        if confidence >= 0.6 { return "Match probabile" }
        return "Match incerto"
    }

    private var color: Color {
        guard let confidence else { return .red }
        if confidence >= 0.9 { return .green }
        if confidence >= 0.6 { return .orange }
        return .red
    }
}

// MARK: - Price Badge

struct PriceBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

// MARK: - GS1 Data Source Footer

struct GS1DataSourceFooter: View {
    let onTapGS1Info: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Dati da fonti pubbliche")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onTapGS1Info) {
                    Text("Come migliorerebbe con GS1?")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Empty State (simple variant for new views)

struct SmartGroceryEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.green.opacity(0.4))
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
