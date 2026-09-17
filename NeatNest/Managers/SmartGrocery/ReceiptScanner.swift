import Foundation
import Vision
import UIKit

enum ReceiptScannerError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return String(localized: "receipt.scan.error.invalidImage", defaultValue: "L'immagine non è leggibile.")
        case .recognitionFailed:
            return String(localized: "receipt.scan.error.failed", defaultValue: "Non riesco a leggere lo scontrino. Riprova con più luce.")
        case .noTextFound:
            return String(localized: "receipt.scan.error.noText", defaultValue: "Non ho trovato testo nella foto.")
        }
    }
}

/// Legge il testo di uno scontrino fotografato.
///
/// Il riconoscimento gira sul dispositivo: la foto dello scontrino non lascia
/// l'iPhone. La correzione linguistica è spenta di proposito — su uno scontrino
/// "MOZZAR.BUFALA" non va corretto in una parola italiana plausibile.
struct ReceiptScanner: Sendable {
    private let parser = ReceiptTextParser()

    func scan(images: [UIImage], referenceDate: Date = Date()) async throws -> ParsedReceipt {
        var allLines: [String] = []

        for image in images {
            allLines.append(contentsOf: try await recognizeLines(in: image))
        }

        guard !allLines.isEmpty else { throw ReceiptScannerError.noTextFound }

        return parser.parse(lines: allLines, referenceDate: referenceDate)
    }

    func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ReceiptScannerError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(throwing: ReceiptScannerError.recognitionFailed)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []

                // Vision non garantisce l'ordine: si riordina dall'alto in basso
                // e, a parità di riga, da sinistra a destra.
                let lines = observations
                    .sorted { lhs, rhs in
                        let deltaY = rhs.boundingBox.midY - lhs.boundingBox.midY
                        if abs(deltaY) > 0.01 { return deltaY < 0 }
                        return lhs.boundingBox.minX < rhs.boundingBox.minX
                    }
                    .compactMap { $0.topCandidates(1).first?.string }

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["it-IT", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ReceiptScannerError.recognitionFailed)
            }
        }
    }
}

private extension UIImage {
    /// Vision lavora su `CGImage`, che non porta con sé l'orientamento: va passato a parte.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
