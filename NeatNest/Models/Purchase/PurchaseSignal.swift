import Foundation

/// Da dove arriva il sospetto che l'utente abbia appena comprato qualcosa.
enum PurchaseSignalSource: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    /// Pagamento Apple Pay, via automazione Wallet delle Scorciatoie.
    case wallet
    /// Uscita da un punto vendita conosciuto.
    case geofence

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .wallet:
            return "Pagamento"
        case .geofence:
            return "Posizione"
        }
    }

    /// Cosa sa questa fonte, e cosa non saprà mai.
    ///
    /// Wallet conosce l'importo esatto ma vede solo Apple Pay. La posizione
    /// vede qualunque acquisto, contanti compresi, ma non sa quanto hai speso.
    var knowsAmount: Bool { self == .wallet }
}

/// Un indizio di acquisto, non ancora un acquisto.
struct PurchaseSignal: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let source: PurchaseSignalSource
    var merchantName: String?
    var amount: Double?
    var retailerId: String?
    let detectedAt: Date

    init(
        id: String = UUID().uuidString,
        source: PurchaseSignalSource,
        merchantName: String? = nil,
        amount: Double? = nil,
        retailerId: String? = nil,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.merchantName = merchantName
        self.amount = amount
        self.retailerId = retailerId
        self.detectedAt = detectedAt
    }
}

/// Quello che si chiede all'utente, una volta soli, per un acquisto.
struct PurchasePrompt: Identifiable, Hashable, Sendable {
    enum Confidence: String, Hashable, Sendable {
        /// Pagamento e posizione dicono la stessa cosa.
        case confirmed
        /// Una sola fonte: utile lo stesso, ma con meno certezze.
        case likely
    }

    let id: String
    let signals: [PurchaseSignal]
    let merchantName: String?
    let amount: Double?
    let retailerId: String?
    let detectedAt: Date
    let confidence: Confidence

    var sources: Set<PurchaseSignalSource> {
        Set(signals.map(\.source))
    }

    /// Il testo della notifica cambia con quello che si sa davvero: promettere
    /// più certezza di quella che si ha è il modo più veloce per farsi ignorare.
    var notificationBody: String {
        switch (merchantName, amount) {
        case let (name?, value?):
            return String(
                localized: "purchase.prompt.merchantAndAmount",
                defaultValue: "Hai speso \(value.formatted(.euro)) da \(name). Scansiona lo scontrino?"
            )
        case let (name?, nil):
            return String(
                localized: "purchase.prompt.merchantOnly",
                defaultValue: "Sei passato da \(name). Hai fatto la spesa?"
            )
        case let (nil, value?):
            return String(
                localized: "purchase.prompt.amountOnly",
                defaultValue: "Hai speso \(value.formatted(.euro)). Vuoi registrarlo?"
            )
        default:
            return String(
                localized: "purchase.prompt.generic",
                defaultValue: "Hai fatto un acquisto? Registralo in un tap."
            )
        }
    }
}
