import SwiftUI

/// Dettaglio ricetta con lo stato reale della dispensa accanto a ogni ingrediente.
struct RecipeDetailView: View {
    let recipeId: String
    let viewModel: RecipeHomeViewModel

    @State private var servings: Int?
    @State private var variantDraft: Recipe?
    @State private var isConfirmingCooked = false
    @State private var isConfirmingDelete = false

    @Environment(\.dismiss) private var dismiss

    private var availability: RecipeAvailability? {
        viewModel.availability(for: recipeId)
    }

    var body: some View {
        Group {
            if let availability {
                content(for: availability)
            } else {
                ContentUnavailableView(
                    "Ricetta non disponibile",
                    systemImage: "fork.knife",
                    description: Text("Questa ricetta non è più nel ricettario.")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $variantDraft) { draft in
            RecipeVariantEditorView(recipe: draft) { edited in
                _Concurrency.Task { await viewModel.save(edited) }
            }
        }
    }

    @ViewBuilder
    private func content(for availability: RecipeAvailability) -> some View {
        let recipe = scaledRecipe(availability.recipe)

        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.displayTitle)
                        .font(.title2.weight(.bold))

                    if let summary = recipe.summary {
                        Text(summary.resolved())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 14) {
                        Label("\(recipe.totalMinutes) min", systemImage: "clock")
                        Label(recipe.difficulty.title, systemImage: "chart.bar")
                        Label(recipe.course.title, systemImage: recipe.course.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    RecipeAvailabilityBadge(availability: availability)
                }
                .padding(.vertical, 4)
            }

            Section {
                Stepper(value: servingsBinding(default: availability.recipe.servings), in: 1...12) {
                    Text("Porzioni: \(recipe.servings)")
                }
            } footer: {
                Text("Le quantità si riscalano da sole.")
            }

            Section("Ingredienti") {
                ForEach(scaledMatches(for: availability)) { match in
                    RecipeIngredientRow(match: match)
                }
            }

            if !availability.blockingMatches.isEmpty {
                Section {
                    Button {
                        _Concurrency.Task { await viewModel.addMissingToShoppingList(availability) }
                    } label: {
                        Label("Aggiungi i mancanti alla lista", systemImage: "cart.badge.plus")
                    }
                }
            }

            Section("Procedimento") {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.displayText)

                            if let minutes = step.minutes {
                                Label("\(minutes) min", systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                Button {
                    isConfirmingCooked = true
                } label: {
                    Label("Ho cucinato questa ricetta", systemImage: "checkmark.circle")
                }
                .disabled(!availability.canCook)

                Button {
                    variantDraft = viewModel.makeVariant(of: availability.recipe)
                } label: {
                    Label("Crea la mia variante", systemImage: "pencil.and.outline")
                }

                if availability.recipe.visibility.isEditable {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Elimina variante", systemImage: "trash")
                    }
                }
            } footer: {
                if let parent = viewModel.parentRecipe(of: availability.recipe) {
                    Text("Variante di “\(parent.displayTitle)”.")
                } else {
                    Text("Le ricette di base non si modificano. Ogni modifica diventa una tua variante, e la ricetta madre resta intatta.")
                }
            }
        }
        .confirmationDialog(
            "Scalare gli ingredienti dalla dispensa?",
            isPresented: $isConfirmingCooked,
            titleVisibility: .visible
        ) {
            Button("Sì, aggiorna la dispensa") {
                _Concurrency.Task { await viewModel.markCooked(availability) }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Verranno tolte le quantità usate dai prodotti che hai in casa.")
        }
        .confirmationDialog(
            "Eliminare questa variante?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                _Concurrency.Task {
                    await viewModel.delete(availability.recipe)
                    dismiss()
                }
            }
            Button("Annulla", role: .cancel) { }
        }
    }

    private func servingsBinding(default defaultValue: Int) -> Binding<Int> {
        Binding(
            get: { servings ?? defaultValue },
            set: { servings = $0 }
        )
    }

    private func scaledRecipe(_ recipe: Recipe) -> Recipe {
        guard let servings else { return recipe }
        return recipe.scaled(toServings: servings)
    }

    /// Lo stato degli ingredienti si calcola sulle quantità originali; qui si
    /// riscalano solo le etichette mostrate.
    private func scaledMatches(for availability: RecipeAvailability) -> [RecipeIngredientMatch] {
        guard let servings, servings != availability.recipe.servings, availability.recipe.servings > 0 else {
            return availability.matches
        }

        let factor = Double(servings) / Double(availability.recipe.servings)

        return availability.matches.map { match in
            var ingredient = match.ingredient
            ingredient.quantity = match.ingredient.quantity.map { $0 * factor }
            return RecipeIngredientMatch(
                ingredient: ingredient,
                status: match.status,
                matchedItemIds: match.matchedItemIds
            )
        }
    }
}
