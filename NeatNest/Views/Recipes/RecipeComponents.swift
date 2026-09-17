import SwiftUI

/// Badge che dice a colpo d'occhio se la ricetta è fattibile adesso.
struct RecipeAvailabilityBadge: View {
    let availability: RecipeAvailability

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var missingCount: Int {
        availability.missingIngredients.count
    }

    private var icon: String {
        availability.canCook ? "checkmark.circle.fill" : "cart.badge.plus"
    }

    private var tint: Color {
        if availability.canCook { return .green }
        return missingCount <= RecipeHomeViewModel.almostThreshold ? .orange : .secondary
    }

    private var label: String {
        availability.canCook
            ? String(localized: "recipes.badge.ready", defaultValue: "Hai tutto")
            : String(localized: "recipes.badge.missing", defaultValue: "Mancano \(missingCount)")
    }
}

/// Riga dell'elenco ricette.
struct RecipeRow: View {
    let availability: RecipeAvailability

    private var recipe: Recipe { availability.recipe }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: recipe.course.icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.displayTitle)
                        .font(.body.weight(.medium))

                    HStack(spacing: 6) {
                        Text(recipe.course.title)
                        Text(verbatim: "·")
                        Text("\(recipe.totalMinutes) min")
                        Text(verbatim: "·")
                        Text(recipe.difficulty.title)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                RecipeAvailabilityBadge(availability: availability)
            }

            if !availability.expiringItemsUsed.isEmpty {
                Label {
                    Text("Usa \(availability.expiringItemsUsed.map(\.displayName).formatted(.list(type: .and)))")
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "clock.badge.exclamationmark")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if recipe.isVariant {
                Label("La tua variante", systemImage: "pencil.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Riga di un ingrediente nel dettaglio, con lo stato rispetto alla dispensa.
struct RecipeIngredientRow: View {
    let match: RecipeIngredientMatch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(match.ingredient.displayName)

                    if match.ingredient.isOptional {
                        Text("facoltativo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
            }

            Spacer(minLength: 4)

            if let quantityLabel = match.ingredient.quantityLabel {
                Text(quantityLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let note = match.ingredient.note {
                Text(note.resolved())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch match.status {
        case .available:
            return "checkmark.circle.fill"
        case .partial:
            return "circle.lefthalf.filled"
        case .missing:
            return "xmark.circle"
        case .optionalMissing:
            return "circle.dashed"
        }
    }

    private var tint: Color {
        switch match.status {
        case .available:
            return .green
        case .partial:
            return .orange
        case .missing:
            return .red
        case .optionalMissing:
            return .secondary
        }
    }

    private var detail: String? {
        switch match.status {
        case .partial(let have, _):
            return String(
                localized: "recipes.ingredient.partial",
                defaultValue: "In dispensa: \(have.formatted())"
            )
        case .missing:
            return String(localized: "recipes.ingredient.missing", defaultValue: "Non ce l'hai")
        case .available, .optionalMissing:
            return nil
        }
    }
}
