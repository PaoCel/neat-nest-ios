import SwiftUI

/// Pallino di stato con l'icona della freschezza.
struct PantryFreshnessBadge: View {
    let freshness: PantryFreshness
    var isEstimated: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: freshness.icon)
                .font(.caption.weight(.semibold))

            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(freshness.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(freshness.tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        switch freshness {
        case .expired:
            return String(localized: "pantry.freshness.expired", defaultValue: "Scaduto")
        case .expiringSoon(let days):
            return days == 0
                ? String(localized: "pantry.freshness.today", defaultValue: "Oggi")
                : String(localized: "pantry.freshness.days", defaultValue: "\(days) g")
        case .fresh(let days):
            return String(localized: "pantry.freshness.days", defaultValue: "\(days) g")
        case .unknown:
            return String(localized: "pantry.freshness.unknown", defaultValue: "—")
        }
    }

    private var accessibilityLabel: String {
        switch freshness {
        case .expired:
            return String(localized: "pantry.freshness.a11y.expired", defaultValue: "Prodotto scaduto")
        case .expiringSoon(let days), .fresh(let days):
            let base = String(localized: "pantry.freshness.a11y.daysLeft", defaultValue: "Scade fra \(days) giorni")
            guard isEstimated else { return base }
            return base + " " + String(localized: "pantry.freshness.a11y.estimated", defaultValue: "(stima)")
        case .unknown:
            return String(localized: "pantry.freshness.a11y.unknown", defaultValue: "Scadenza non impostata")
        }
    }
}

/// Filtro rapido per posizione, sopra la lista.
struct PantryStorageFilterBar: View {
    @Binding var selection: PantryStorage?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(
                    title: String(localized: "pantry.filter.all", defaultValue: "Tutto"),
                    icon: "square.grid.2x2",
                    isSelected: selection == nil
                ) {
                    selection = nil
                }

                ForEach(PantryStorage.allCases) { storage in
                    chip(
                        title: String(localized: storage.title),
                        icon: storage.icon,
                        isSelected: selection == storage
                    ) {
                        selection = selection == storage ? nil : storage
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Riga prodotto: nome, quantità, scadenza, provenienza.
struct PantryItemRow: View {
    let item: PantryItem
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 38

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.category.tintColor.opacity(0.15))
                Image(systemName: item.category.iconName)
                    .font(.system(size: iconSize * 0.42))
                    .foregroundStyle(item.category.tintColor)
            }
            .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.quantity.formatted())

                    if item.isQuantityEstimated {
                        Text(verbatim: "·")
                        Text(item.level.title)
                    } else if item.isOpened {
                        Text(verbatim: "·")
                        Text("Aperto")
                    }

                    if let expiresAt = item.expiresAt {
                        Text(verbatim: "·")
                        Text(expiresAt, format: .dateTime.day().month(.abbreviated))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            PantryFreshnessBadge(freshness: item.freshness(), isEstimated: item.isExpiryEstimated)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Il controllo con cui si dichiara quanto resta: quattro opzioni, un tap.
///
/// Non esiste un campo numerico di proposito. Chiedere i grammi di un prodotto
/// aperto significa non ricevere risposta.
struct PantryLevelPicker: View {
    let item: PantryItem
    let onSelect: (PantryLevel) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PantryLevel.openedCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: level.icon)
                            .font(.subheadline)
                        Text(level.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(level == item.level ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                    )
                    .foregroundStyle(level == item.level ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(level == item.level ? [.isSelected] : [])
            }
        }
    }
}

/// La domanda che si fa una volta sola, quando serve davvero: il prodotto sta
/// scadendo e non sappiamo quanto ne resta.
struct PantryLevelPrompt: View {
    let item: PantryItem
    let onSelect: (PantryLevel) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.displayName) — ancora buono?")
                        .font(.subheadline.weight(.semibold))

                    Text("Scade presto. Un tap e la dispensa resta affidabile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Chiudi la domanda"))
            }

            PantryLevelPicker(item: item, onSelect: onSelect)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }
}

/// Banner in cima alla dispensa quando c'è roba che sta per andare a male.
struct PantryExpiringBanner: View {
    let items: [PantryItem]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(items.count) prodotti da usare")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        items.prefix(3)
            .map(\.displayName)
            .formatted(.list(type: .and))
    }
}

// MARK: - Preview

private extension PantryItem {
    static func preview(
        name: String,
        quantity: PantryQuantity,
        category: GrocerySpendingCategory,
        storage: PantryStorage,
        expiresInDays: Int?,
        isOpened: Bool = false
    ) -> PantryItem {
        PantryItem(
            userId: "preview",
            name: LocalizedContent(source: name),
            quantity: quantity,
            storage: storage,
            category: category,
            openedAt: isOpened ? Date() : nil,
            expiresAt: expiresInDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) },
            isExpiryEstimated: true
        )
    }

    static var previewItems: [PantryItem] {
        [
            .preview(
                name: "Latte Arborea",
                quantity: PantryQuantity(value: 1, unit: .liter),
                category: .dairy,
                storage: .fridge,
                expiresInDays: 2,
                isOpened: true
            ),
            .preview(
                name: "Yogurt greco",
                quantity: PantryQuantity(value: 4, unit: .piece),
                category: .dairy,
                storage: .fridge,
                expiresInDays: -1
            ),
            .preview(
                name: "Rigatoni",
                quantity: PantryQuantity(value: 500, unit: .gram),
                category: .pantry,
                storage: .pantry,
                expiresInDays: 320
            ),
            .preview(
                name: "Guanciale",
                quantity: PantryQuantity(value: 200, unit: .gram),
                category: .protein,
                storage: .fridge,
                expiresInDays: 6
            ),
            .preview(
                name: "Sale grosso",
                quantity: PantryQuantity(value: 1, unit: .pack),
                category: .pantry,
                storage: .pantry,
                expiresInDays: nil
            )
        ]
    }
}

#Preview("Righe dispensa") {
    List {
        Section {
            ForEach(PantryItem.previewItems) { item in
                PantryItemRow(item: item)
            }
        } header: {
            Label("Frigo", systemImage: "refrigerator")
        }
    }
}

#Preview("Banner e filtri") {
    @Previewable @State var storage: PantryStorage?

    return VStack(spacing: 20) {
        PantryExpiringBanner(items: Array(PantryItem.previewItems.prefix(3))) { }
            .padding(.horizontal, 20)

        PantryStorageFilterBar(selection: $storage)

        Spacer()
    }
    .padding(.top, 24)
}

/// Un prodotto che, a giudicare dalle abitudini, dovrebbe essere finito.
struct RepurchaseSuggestionRow: View {
    let suggestion: RepurchaseSuggestion
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onAdd) {
                Image(systemName: "cart.badge.plus")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Aggiungi alla lista della spesa"))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Non suggerire più"))
        }
        .padding(.vertical, 2)
    }

    /// Si dice il perché, non solo il cosa: un suggerimento senza motivo è un
    /// comando, e l'utente non si fida dei comandi che non capisce.
    private var detail: String {
        String(
            localized: "pantry.repurchase.detail",
            defaultValue: "Di solito ogni \(suggestion.typicalIntervalDays) giorni · ultimo acquisto \(suggestion.daysSinceLastPurchase) giorni fa"
        )
    }
}
