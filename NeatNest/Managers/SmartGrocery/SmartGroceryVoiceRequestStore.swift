import Foundation

final class SmartGroceryVoiceRequestStore {
    static let shared = SmartGroceryVoiceRequestStore()

    private let defaults: UserDefaults
    private let pendingRequestKey = "smartGrocery.voice.pendingRequest"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savePendingRequest(rawInputText: String) {
        let request = PendingSmartGroceryVoiceRequest(rawInputText: rawInputText)
        save(request)
    }

    func loadPendingRequest() -> PendingSmartGroceryVoiceRequest? {
        guard let data = defaults.data(forKey: pendingRequestKey) else {
            return nil
        }

        return try? JSONDecoder().decode(PendingSmartGroceryVoiceRequest.self, from: data)
    }

    func clearPendingRequest() {
        defaults.removeObject(forKey: pendingRequestKey)
    }

    private func save(_ request: PendingSmartGroceryVoiceRequest) {
        guard let data = try? JSONEncoder().encode(request) else {
            return
        }

        defaults.set(data, forKey: pendingRequestKey)
    }
}
