import SwiftUI

/// Inserimento di un movimento: importo, nota, data. Tre campi, niente altro.
struct MoneyEntryEditorView: View {
    let kind: MoneyEntry.Kind
    let onSave: (Double, String, Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 0
    @State private var note = ""
    @State private var date = Date()
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(verbatim: "€")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField(
                            "0,00",
                            value: $amount,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .font(.title2.weight(.semibold))
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                    }
                }

                Section {
                    TextField("Descrizione", text: $note)
                        .textInputAutocapitalization(.sentences)

                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        onSave(amount, note, date)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
            .onAppear {
                // La tastiera si apre da sola sull'importo: è l'unico campo
                // davvero obbligatorio.
                isAmountFocused = true
            }
        }
    }
}
