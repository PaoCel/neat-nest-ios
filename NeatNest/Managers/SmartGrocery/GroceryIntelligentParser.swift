import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Interpreta una frase libera nella lista della spesa, usando il modello
/// on-device quando c'è.
///
/// Apple Intelligence è un miglioramento, non un requisito: il modello gira solo
/// su iOS 26 e su dispositivi che lo supportano. Dove non c'è — ed è la maggior
/// parte del parco macchine — resta `GroceryPhraseParser`, che è deterministico
/// e non sbaglia mai in modo creativo.
struct GroceryIntelligentParser: Sendable {
    private let fallback = GroceryPhraseParser()

    init() { }

    /// Il modello on-device è utilizzabile qui e ora?
    static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func parse(_ text: String) async -> [GroceryDraftItem] {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return [] }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            if let items = await parseWithModel(trimmed), !items.isEmpty {
                return items
            }
        }
        #endif

        return fallback.parse(trimmed)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func parseWithModel(_ text: String) async -> [GroceryDraftItem]? {
        let session = LanguageModelSession(
            instructions: """
            Ricevi una frase detta a voce da chi sta compilando la lista della spesa.
            Estrai gli articoli distinti, uno per prodotto.
            Riporta la quantità solo se è detta esplicitamente, altrimenti usa 1.
            Non inventare prodotti che non sono stati nominati.
            Il nome dell'articolo va lasciato in italiano, senza articoli iniziali.
            """
        )

        do {
            let response = try await session.respond(to: text, generating: GeneratedGroceryList.self)
            return response.content.items.map { item in
                GroceryDraftItem(
                    name: item.name.trimmed,
                    quantity: max(item.quantity ?? 1, 0.01),
                    unit: item.unit?.trimmed.isEmpty == false ? item.unit?.trimmed : nil
                )
            }
            .filter { $0.name.count >= 2 }
        } catch {
            // Modello occupato, contenuto rifiutato, qualunque cosa: si torna al
            // parser deterministico invece di far fallire l'inserimento.
            return nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedGroceryList {
    @Guide(description: "Gli articoli della spesa nominati nella frase, uno per prodotto distinto")
    var items: [GeneratedGroceryItem]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedGroceryItem {
    @Guide(description: "Nome del prodotto, senza articoli e senza quantità")
    var name: String

    @Guide(description: "Quantità richiesta, 1 se non specificata")
    var quantity: Double?

    @Guide(description: "Unità di misura se detta: l, ml, kg, g, conf")
    var unit: String?
}
#endif
