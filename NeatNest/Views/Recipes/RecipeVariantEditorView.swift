import SwiftUI

/// Editor della variante personale di una ricetta.
///
/// Si apre già popolato con la ricetta madre: l'utente cambia quello che vuole
/// e salva. La madre non viene toccata.
struct RecipeVariantEditorView: View {
    @State private var recipe: Recipe
    private let onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    @State private var summaryText: String

    init(recipe: Recipe, onSave: @escaping (Recipe) -> Void) {
        _recipe = State(initialValue: recipe)
        _titleText = State(initialValue: recipe.displayTitle)
        _summaryText = State(initialValue: recipe.summary?.resolved() ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ricetta") {
                    TextField("Titolo", text: $titleText)

                    TextField("Descrizione", text: $summaryText, axis: .vertical)
                        .lineLimit(1...3)

                    Stepper(value: $recipe.servings, in: 1...12) {
                        Text("Porzioni: \(recipe.servings)")
                    }

                    Stepper(value: $recipe.prepMinutes, in: 0...240, step: 5) {
                        Text("Preparazione: \(recipe.prepMinutes) min")
                    }

                    Stepper(value: $recipe.cookMinutes, in: 0...480, step: 5) {
                        Text("Cottura: \(recipe.cookMinutes) min")
                    }

                    Picker("Difficoltà", selection: $recipe.difficulty) {
                        ForEach(RecipeDifficulty.allCases) { difficulty in
                            Text(difficulty.title).tag(difficulty)
                        }
                    }

                    Picker("Portata", selection: $recipe.course) {
                        ForEach(RecipeCourse.allCases) { course in
                            Text(course.title).tag(course)
                        }
                    }
                }

                Section("Ingredienti") {
                    ForEach($recipe.ingredients) { $ingredient in
                        IngredientEditorRow(ingredient: $ingredient)
                    }
                    .onDelete { recipe.ingredients.remove(atOffsets: $0) }
                    .onMove { recipe.ingredients.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        recipe.ingredients.append(
                            RecipeIngredient(name: LocalizedContent(source: ""), quantity: nil, unit: nil)
                        )
                    } label: {
                        Label("Aggiungi ingrediente", systemImage: "plus.circle")
                    }
                }

                Section("Procedimento") {
                    ForEach($recipe.steps) { $step in
                        StepEditorRow(step: $step)
                    }
                    .onDelete { recipe.steps.remove(atOffsets: $0) }
                    .onMove { recipe.steps.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        recipe.steps.append(RecipeStep(text: LocalizedContent(source: "")))
                    } label: {
                        Label("Aggiungi passo", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("La mia variante")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                    }
                    .disabled(titleText.trimmed.isEmpty)
                }

                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }

    private func save() {
        var edited = recipe
        edited.title = LocalizedContent(source: titleText.trimmed)
        edited.summary = summaryText.trimmed.isEmpty ? nil : LocalizedContent(source: summaryText.trimmed)
        edited.ingredients = recipe.ingredients.filter { !$0.displayName.trimmed.isEmpty }
        edited.steps = recipe.steps.filter { !$0.displayText.trimmed.isEmpty }

        onSave(edited)
        dismiss()
    }
}

private struct IngredientEditorRow: View {
    @Binding var ingredient: RecipeIngredient

    @State private var nameText: String = ""
    @State private var quantityValue: Double = 0
    @State private var unitSelection: PantryUnit?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ingrediente", text: $nameText)
                .onChange(of: nameText) { _, newValue in
                    ingredient.name = LocalizedContent(source: newValue)
                    ingredient.matchTokens = RecipeTextNormalizer.tokens(from: newValue)
                }

            HStack(spacing: 10) {
                TextField(
                    "Quantità",
                    value: $quantityValue,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                .onChange(of: quantityValue) { _, newValue in
                    ingredient.quantity = newValue > 0 ? newValue : nil
                }

                Picker("Unità", selection: $unitSelection) {
                    Text("—").tag(PantryUnit?.none)
                    ForEach(PantryUnit.allCases) { unit in
                        Text(unit.pickerLabel).tag(PantryUnit?.some(unit))
                    }
                }
                .labelsHidden()
                .onChange(of: unitSelection) { _, newValue in
                    ingredient.unit = newValue
                }

                Spacer(minLength: 0)

                Toggle(isOn: $ingredient.isOptional) {
                    Text("Facoltativo")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            nameText = ingredient.displayName
            quantityValue = ingredient.quantity ?? 0
            unitSelection = ingredient.unit
        }
    }
}

private struct StepEditorRow: View {
    @Binding var step: RecipeStep

    @State private var text: String = ""

    var body: some View {
        TextField("Passo", text: $text, axis: .vertical)
            .lineLimit(1...5)
            .onChange(of: text) { _, newValue in
                step.text = LocalizedContent(source: newValue)
            }
            .onAppear { text = step.displayText }
    }
}
