import SwiftUI

/// Scheda di inserimento di un prodotto in dispensa.
///
/// Quantità, categoria e posizione hanno default sensati: nel caso rapido
/// l'utente scrive solo il nome e salva. La scadenza, se non la imposta lui,
/// viene stimata dalla shelf life della categoria.
struct PantryItemEditorView: View {
    let viewModel: PantryHomeViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var quantityValue: Double = 1
    @State private var unit: PantryUnit = .piece
    @State private var category: GrocerySpendingCategory = .other
    @State private var storage: PantryStorage?
    @State private var hasExplicitExpiry = false
    @State private var expiresAt = Date()
    @State private var isOpened = false
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome prodotto", text: $name)
                        .textInputAutocapitalization(.sentences)

                    HStack {
                        TextField(
                            "Quantità",
                            value: $quantityValue,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)

                        Picker("Unità", selection: $unit) {
                            ForEach(PantryUnit.allCases) { unit in
                                Text(unit.pickerLabel).tag(unit)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("Classificazione") {
                    Picker("Categoria", selection: $category) {
                        ForEach(GrocerySpendingCategory.allCases) { category in
                            Label {
                                Text(category.title)
                            } icon: {
                                Image(systemName: category.iconName)
                            }
                            .tag(category)
                        }
                    }

                    Picker("Posizione", selection: $storage) {
                        Text("Automatica").tag(PantryStorage?.none)
                        ForEach(PantryStorage.allCases) { storage in
                            Label {
                                Text(storage.title)
                            } icon: {
                                Image(systemName: storage.icon)
                            }
                            .tag(PantryStorage?.some(storage))
                        }
                    }
                }

                Section {
                    Toggle("Già aperto", isOn: $isOpened)

                    Toggle("Imposto io la scadenza", isOn: $hasExplicitExpiry.animation())

                    if hasExplicitExpiry {
                        DatePicker(
                            "Scade il",
                            selection: $expiresAt,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    } else if let estimate = estimatedExpiry {
                        LabeledContent("Scadenza stimata") {
                            Text(estimate, format: .dateTime.day().month(.abbreviated).year())
                        }
                    }
                } header: {
                    Text("Scadenza")
                } footer: {
                    if !hasExplicitExpiry {
                        Text("La stima viene dalla categoria e da dove lo conservi. Puoi correggerla quando vuoi.")
                    }
                }

                Section("Note") {
                    TextField("Note", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Nuovo prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        _Concurrency.Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Dispensa", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: category) { _, newValue in
                // Le unità sensate cambiano con la categoria: i liquidi non si contano a pezzi.
                if unit == .piece, newValue == .beverages {
                    unit = .liter
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmed.isEmpty && quantityValue > 0
    }

    private var estimatedExpiry: Date? {
        guard !name.trimmed.isEmpty else { return nil }

        return ShelfLifeCatalog.estimatedExpiry(
            productName: name.trimmed,
            category: category,
            storage: storage ?? PantryStorage.suggested(for: category),
            openedAt: isOpened ? Date() : nil
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let item = try viewModel.makeItem(
                name: name,
                quantity: PantryQuantity(value: quantityValue, unit: unit),
                category: category,
                storage: storage,
                expiresAt: hasExplicitExpiry ? expiresAt : nil,
                isOpened: isOpened,
                notes: notes
            )

            await viewModel.save(item)
            dismiss()
        } catch let error as PantryError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = PantryError.persistenceFailed.errorDescription
        }
    }
}
