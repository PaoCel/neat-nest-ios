import Foundation
import UserNotifications
import Observation

/// Dove va l'utente quando tocca un bottone della notifica di acquisto.
///
/// Il tap non deve finire nel nulla: chi risponde "scansiona" si aspetta la
/// fotocamera, chi risponde "registra" si aspetta il campo importo già pieno.
@MainActor
@Observable
final class PurchaseNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    /// Dove l'app deve portare l'utente al prossimo giro di render.
    enum Route: Hashable {
        case scanReceipt
        case logExpense(amount: Double, merchantName: String)
    }

    static let shared = PurchaseNotificationHandler()

    private(set) var pendingRoute: Route?

    func consumeRoute() -> Route? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Anche con l'app aperta la notifica si mostra: è una domanda, non un
        // avviso di sistema.
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let promptId = userInfo["promptId"] as? String
        let amount = userInfo["amount"] as? Double ?? 0
        let merchantName = userInfo["merchantName"] as? String ?? ""
        let action = response.actionIdentifier

        await MainActor.run {
            switch action {
            case PurchaseNotifier.scanActionIdentifier:
                pendingRoute = .scanReceipt
            case PurchaseNotifier.logActionIdentifier:
                pendingRoute = .logExpense(amount: amount, merchantName: merchantName)
            case UNNotificationDefaultActionIdentifier:
                // Tap sul corpo: si va dove si sa fare di più. Con un importo in
                // mano conviene registrare, altrimenti si scansiona.
                pendingRoute = amount > 0
                    ? .logExpense(amount: amount, merchantName: merchantName)
                    : .scanReceipt
            default:
                break
            }
        }

        if let promptId {
            await PurchaseDetectionManager.shared.resolve(promptId: promptId)
        }
    }
}
