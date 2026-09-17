import AppIntents
import Foundation

struct AddToSmartGroceryIntent: AppIntent {
    static let title: LocalizedStringResource = "Aggiungi a Smart Grocery"
    static let description = IntentDescription("Aggiunge un articolo alla lista principale Smart Grocery di NeatNest.")
    static let openAppWhenRun = true

    @Parameter(
        title: "Articolo",
        requestValueDialog: IntentDialog("Quale prodotto vuoi aggiungere alla Smart Grocery?")
    )
    var productDescription: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedText = productDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return .result(dialog: IntentDialog("Dimmi quale prodotto vuoi aggiungere."))
        }

        SmartGroceryVoiceRequestStore.shared.savePendingRequest(rawInputText: trimmedText)

        return .result(
            dialog: IntentDialog("Apro NeatNest e aggiungo \(trimmedText) alla tua Smart Grocery.")
        )
    }
}

struct NeatNestSmartGroceryShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .teal
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToSmartGroceryIntent(),
            phrases: [
                "Aggiungi alla Smart Grocery di \(.applicationName)",
                "Apri Smart Grocery di \(.applicationName)"
            ],
            shortTitle: "Aggiungi spesa",
            systemImageName: "cart.badge.plus"
        )
    }
}
