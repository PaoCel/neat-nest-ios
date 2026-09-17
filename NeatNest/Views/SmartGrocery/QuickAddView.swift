import SwiftUI

/// Il modo più veloce per segnarsi le cose: scrivi e vai a capo.
///
/// Nessun campo quantità, nessun selettore unità, nessuna categoria. Chi si
/// segna la spesa lo fa in piedi davanti al frigo, con una mano sola.
struct QuickAddView: View {
    let userId: String
    let onAdded: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private let parser = GroceryPhraseParser()
    private let service = SmartGroceryService()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $text)
                    .font(.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("latte\npane\ndue chili di patate")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 21)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }

                if !preview.isEmpty {
                    Divider()

                    previewSection
                }
            }
            .navigationTitle("Aggiungi alla lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") {
                        _Concurrency.Task { await save() }
                    }
                    .disabled(preview.isEmpty || isSaving)
                }
            }
            .alert("Lista della spesa", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { isFocused = true }
        }
    }

    /// Mostra come verrà interpretato prima di salvare: chi scrive "due chili di
    /// patate" deve vedere subito che l'app ha capito 2 kg, non "due".
    private var preview: [GroceryDraftItem] {
        parser.parse(text)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(preview.count) articoli")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(preview, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item.name)

                            if item.quantity != 1 || item.unit != nil {
                                Text(quantityLabel(for: item))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 12)
        }
    }

    private func quantityLabel(for item: GroceryDraftItem) -> String {
        let number = item.quantity.formatted(.number.precision(.fractionLength(0...2)))
        guard let unit = item.unit else { return "×\(number)" }
        return "\(number) \(unit)"
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let created = try await service.addItems(fromText: text, userId: userId)
            onAdded(created.count)
            dismiss()
        } catch {
            errorMessage = String(
                localized: "grocery.quickAdd.error",
                defaultValue: "Non riesco ad aggiungere gli articoli. Riprova."
            )
        }
    }
}
