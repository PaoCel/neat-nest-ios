import AppIntents
import Foundation

/// L'aggancio per l'automazione Wallet delle Scorciatoie.
///
/// L'utente crea un'automazione "Wallet" (in iOS 17 si chiamava "Transazione")
/// che a ogni pagamento Apple Pay lancia questa azione con importo ed esercente.
/// NeatNest se li segna e chiede se registrare la spesa.
///
/// Non apre l'app: scattare in primo piano a ogni pagamento sarebbe invadente.
/// Arriva una notifica, e si decide da lì.
struct LogWalletPurchaseIntent: AppIntent {
    static let title: LocalizedStringResource = "Registra pagamento"
    // La descrizione di un App Intent non può contenere la parola "apple":
    // App Store Connect rifiuta il binario con ITMS-90626.
    static let description = IntentDescription(
        "Segna un pagamento in NeatNest, così puoi registrarlo fra le spese o collegarlo allo scontrino."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Importo")
    var amount: Double

    @Parameter(title: "Esercente")
    var merchantName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: IntentDialog("Importo non valido."))
        }

        await PurchaseDetectionManager.shared.recordWalletTransaction(
            amount: amount,
            merchantName: merchantName
        )

        return .result(dialog: IntentDialog("Segnato. Te lo chiedo fra un attimo."))
    }
}
