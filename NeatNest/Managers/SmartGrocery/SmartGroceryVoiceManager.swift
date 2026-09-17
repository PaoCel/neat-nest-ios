import Foundation

@MainActor
final class SmartGroceryVoiceManager: ObservableObject {
    @Published private(set) var lastProcessedResult: SmartGroceryVoiceProcessedResult?
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    private let requestStore: SmartGroceryVoiceRequestStore
    private let service: SmartGroceryService
    private var lastProcessedRequestId: String?

    init(
        requestStore: SmartGroceryVoiceRequestStore = .shared,
        service: SmartGroceryService? = nil
    ) {
        self.requestStore = requestStore
        self.service = service ?? SmartGroceryService()
    }

    func processPendingRequestIfPossible(userId: String?) async {
        guard !isProcessing,
              let userId,
              !userId.isEmpty,
              let pendingRequest = requestStore.loadPendingRequest(),
              pendingRequest.id != lastProcessedRequestId else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let (defaultList, creationResult) = try await service.processVoiceItemAddition(
                userId: userId,
                rawInputText: pendingRequest.rawInputText
            )

            lastProcessedResult = SmartGroceryVoiceProcessedResult(
                listId: defaultList.id,
                listTitle: defaultList.title,
                itemName: creationResult.item.displayName,
                rawInputText: creationResult.item.rawInputText,
                suggestion: creationResult.suggestion
            )

            lastProcessedRequestId = pendingRequest.id
            requestStore.clearPendingRequest()
        } catch {
            errorMessage = "Non riesco ad aggiungere l'articolo con Siri. \(error.localizedDescription)"
        }
    }

    func clearLastProcessedResult() {
        lastProcessedResult = nil
    }
}

extension SmartGroceryVoiceManager {
    convenience init(previewResult: SmartGroceryVoiceProcessedResult?, errorMessage: String? = nil) {
        self.init(requestStore: .shared, service: SmartGroceryService(catalogCache: SeededProductCatalog.items))
        self.lastProcessedResult = previewResult
        self.errorMessage = errorMessage
    }
}
