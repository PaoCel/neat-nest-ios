import Foundation
import UserNotifications

/// Chiede all'utente se ha appena comprato qualcosa.
///
/// Una notifica per acquisto, mai due, e con i bottoni giusti sopra: chi è
/// appena uscito dal supermercato non ha voglia di aprire un'app e navigare.
@MainActor
final class PurchaseNotifier {
    static let categoryIdentifier = "purchase-prompt"
    static let scanActionIdentifier = "purchase-scan"
    static let logActionIdentifier = "purchase-log"
    static let dismissActionIdentifier = "purchase-dismiss"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Registra i bottoni della notifica. Va fatto all'avvio, prima che arrivi
    /// la prima notifica.
    func registerCategory() {
        let scan = UNNotificationAction(
            identifier: Self.scanActionIdentifier,
            title: String(localized: "purchase.action.scan", defaultValue: "Scansiona scontrino"),
            options: [.foreground]
        )

        let log = UNNotificationAction(
            identifier: Self.logActionIdentifier,
            title: String(localized: "purchase.action.log", defaultValue: "Registra spesa"),
            options: [.foreground]
        )

        let dismiss = UNNotificationAction(
            identifier: Self.dismissActionIdentifier,
            title: String(localized: "purchase.action.dismiss", defaultValue: "No, grazie"),
            options: [.destructive]
        )

        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryIdentifier,
                actions: [scan, log, dismiss],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            // Negato è una risposta: non si richiede.
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    func notify(_ prompt: PurchasePrompt) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "purchase.prompt.title", defaultValue: "Acquisto rilevato")
        content.body = prompt.notificationBody
        content.categoryIdentifier = Self.categoryIdentifier
        content.sound = .default
        content.userInfo = [
            "promptId": prompt.id,
            "amount": prompt.amount ?? 0,
            "merchantName": prompt.merchantName ?? ""
        ]

        // La stessa richiesta non deve mai comparire due volte: l'identificativo
        // è costruito sui segnali che l'hanno generata.
        let request = UNNotificationRequest(identifier: prompt.id, content: content, trigger: nil)
        try? await center.add(request)
    }

    func cancel(promptId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [promptId])
        center.removeDeliveredNotifications(withIdentifiers: [promptId])
    }
}
