import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ReceiptScanViewModel {
    private(set) var isProcessing = false
    private(set) var lastResult: ReceiptIntakeResult?
    var errorMessage: String?

    private let userId: String
    private let intakeService: ReceiptIntakeService

    init(userId: String, intakeService: ReceiptIntakeService? = nil) {
        self.userId = userId
        self.intakeService = intakeService ?? ReceiptIntakeService()
    }

    var canScan: Bool {
        ReceiptScannerView.isAvailable
    }

    func process(images: [UIImage]) async {
        guard !images.isEmpty else { return }

        isProcessing = true
        errorMessage = nil
        lastResult = nil
        defer { isProcessing = false }

        do {
            lastResult = try await intakeService.process(images: images, userId: userId)
        } catch let error as ReceiptScannerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = String(
                localized: "receipt.intake.error",
                defaultValue: "Non riesco a registrare questo scontrino. Riprova."
            )
        }
    }

    func clear() {
        lastResult = nil
    }
}
