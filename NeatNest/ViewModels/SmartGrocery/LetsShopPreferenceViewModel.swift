import Foundation
import Observation

@MainActor
@Observable
final class LetsShopPreferenceViewModel {
    var preferenceValue: Double
    private(set) var preparation: LetsShopPreparationSummary?
    private(set) var isLoading = false
    private(set) var isGenerating = false
    var errorMessage: String?

    let list: UserGroceryList

    private let userId: String?
    private let service: LetsShopService
    private var hasLoaded = false
    private var previewRecommendationSet: ShoppingRecommendationSet?

    init(
        list: UserGroceryList,
        userSession: UserSession,
        service: LetsShopService? = nil
    ) {
        self.list = list
        self.userId = userSession.currentUserId
        self.service = service ?? LetsShopService()
        self.preferenceValue = Self.initialPreferenceValue()
    }

    var selectedMode: ShoppingRecommendationKind {
        ShoppingRecommendationKind.fromSliderValue(preferenceValue)
    }

    var activeItemsCount: Int {
        preparation?.activeCount ?? 0
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let userId, !userId.isEmpty else {
            errorMessage = "Non riesco a capire quale account usare per il piano spesa."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            preparation = try await service.loadPreparation(for: list, userId: userId)
        } catch {
            errorMessage = "Non riesco a preparare il flusso Let's Shop. \(error.localizedDescription)"
        }
    }

    func generateRecommendations(considerLoyaltyPricing: Bool) async -> ShoppingRecommendationSet? {
        if let previewRecommendationSet {
            return previewRecommendationSet
        }

        guard let userId, !userId.isEmpty else {
            errorMessage = "Account non disponibile."
            return nil
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            return try await service.generateRecommendations(
                for: list,
                userId: userId,
                preferenceValue: preferenceValue,
                considerLoyaltyPricing: considerLoyaltyPricing
            )
        } catch {
            errorMessage = "Non riesco a calcolare il piano spesa. \(error.localizedDescription)"
            return nil
        }
    }
}

private extension LetsShopPreferenceViewModel {
    static func initialPreferenceValue() -> Double {
        let storedStyle = UserDefaults.standard.string(forKey: "smartGrocery.preferenceStyle")

        switch GroceryPreferenceStyle(rawValue: storedStyle ?? "") {
        case .speed:
            return 18
        case .savings:
            return 84
        case .balanced, .none:
            return 50
        }
    }
}

extension LetsShopPreferenceViewModel {
    convenience init(
        previewList: UserGroceryList,
        preparation: LetsShopPreparationSummary,
        recommendationSet: ShoppingRecommendationSet,
        preferenceValue: Double
    ) {
        self.init(list: previewList, userSession: PreviewSupport.makeUserSession())
        self.preparation = preparation
        self.preferenceValue = preferenceValue
        self.previewRecommendationSet = recommendationSet
        self.hasLoaded = true
    }
}
