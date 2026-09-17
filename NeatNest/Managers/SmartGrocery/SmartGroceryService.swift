import Foundation

@MainActor
final class SmartGroceryService {
    private let repository: SmartGroceryRepository
    private let matcher: GroceryCatalogMatcher

    private(set) var catalogCache: [ProductCatalogItem]

    init(
        repository: SmartGroceryRepository = SmartGroceryRepository(),
        matcher: GroceryCatalogMatcher = GroceryCatalogMatcher(),
        catalogCache: [ProductCatalogItem] = SeededProductCatalog.items
    ) {
        self.repository = repository
        self.matcher = matcher
        self.catalogCache = catalogCache
    }

    func prepareCatalog() async -> [ProductCatalogItem] {
        do {
            let remoteCatalog = try await repository.fetchCatalog()
            if !remoteCatalog.isEmpty {
                catalogCache = remoteCatalog
            } else {
                catalogCache = SeededProductCatalog.items
            }
        } catch {
            catalogCache = SeededProductCatalog.items
        }

        return catalogCache
    }

    func ensureDefaultList(for userId: String) async throws -> UserGroceryList {
        let existingLists = try await repository.fetchLists(for: userId)

        if let defaultList = existingLists.first(where: { $0.isDefault }) {
            return defaultList
        }

        if let firstList = existingLists.first {
            try await repository.setListDefault(listId: firstList.id, isDefault: true)
            var updatedList = firstList
            updatedList.isDefault = true
            updatedList.updatedAt = Date()
            return updatedList
        }

        return try await repository.createList(
            userId: userId,
            title: "Lista principale",
            isDefault: true
        )
    }

    func createList(userId: String, title: String) async throws -> UserGroceryList {
        try await repository.createList(userId: userId, title: title, isDefault: false)
    }

    func renameList(_ list: UserGroceryList, title: String) async throws {
        try await repository.updateListTitle(listId: list.id, title: title)
    }

    func deleteList(_ list: UserGroceryList) async throws {
        try await repository.deleteList(listId: list.id, userId: list.userId)
    }

    func match(rawInputText: String) -> GroceryCatalogMatch? {
        matcher.bestMatch(for: rawInputText, within: catalogCache)
    }

    func createItem(listId: String, userId: String, draft: GroceryItemDraft) async throws -> UserGroceryListItem {
        try await createItemResult(listId: listId, userId: userId, draft: draft).item
    }

    func createItemResult(
        listId: String,
        userId: String,
        draft: GroceryItemDraft
    ) async throws -> GroceryItemCreationResult {
        if catalogCache.isEmpty {
            _ = await prepareCatalog()
        }

        let trimmedRawText = draft.rawInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalogMatch = match(rawInputText: trimmedRawText)
        let newItem = UserGroceryListItem(
            listId: listId,
            userId: userId,
            rawInputText: trimmedRawText,
            normalizedName: catalogMatch?.product.canonicalName,
            productCatalogId: catalogMatch?.product.id,
            quantity: max(0.5, draft.quantity),
            unit: sanitizedString(draft.unit),
            status: .active,
            createdAt: Date(),
            updatedAt: Date(),
            lastPurchasedAt: nil,
            notes: sanitizedString(draft.notes),
            catalogEnrichmentStatus: catalogMatch == nil ? .queued : .resolved,
            catalogEnrichmentSource: catalogMatch == nil ? "local-fallback" : "local-catalog",
            catalogEnrichmentConfidence: catalogMatch == nil ? nil : 1,
            catalogEnrichmentUpdatedAt: Date()
        )

        try await repository.createItem(newItem)
        let suggestion = try await makeReactivationSuggestion(for: newItem, userId: userId)
        return GroceryItemCreationResult(item: newItem, suggestion: suggestion)
    }

    func updateItem(_ item: UserGroceryListItem, with draft: GroceryItemDraft) async throws -> UserGroceryListItem {
        if catalogCache.isEmpty {
            _ = await prepareCatalog()
        }

        let trimmedRawText = draft.rawInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalogMatch = match(rawInputText: trimmedRawText)
        let rawInputDidChange = item.rawInputText.trimmingCharacters(in: .whitespacesAndNewlines) != trimmedRawText

        var updatedItem = item
        updatedItem.rawInputText = trimmedRawText
        updatedItem.normalizedName = catalogMatch?.product.canonicalName
        updatedItem.productCatalogId = catalogMatch?.product.id
        updatedItem.quantity = max(0.5, draft.quantity)
        updatedItem.unit = sanitizedString(draft.unit)
        updatedItem.notes = sanitizedString(draft.notes)
        updatedItem.updatedAt = Date()

        if rawInputDidChange {
            updatedItem.catalogEnrichmentStatus = catalogMatch == nil ? .queued : .resolved
            updatedItem.catalogEnrichmentSource = catalogMatch == nil ? "local-fallback" : "local-catalog"
            updatedItem.catalogEnrichmentConfidence = catalogMatch == nil ? nil : 1
            updatedItem.catalogEnrichmentUpdatedAt = Date()
        }

        try await repository.updateItem(updatedItem)
        return updatedItem
    }

    func updateQuantity(for item: UserGroceryListItem, delta: Double) async throws -> UserGroceryListItem {
        var updatedItem = item
        updatedItem.quantity = max(0.5, item.quantity + delta)
        updatedItem.updatedAt = Date()

        try await repository.updateItem(updatedItem)
        return updatedItem
    }

    func setStatus(for item: UserGroceryListItem, status: GroceryItemStatus) async throws -> UserGroceryListItem {
        var updatedItem = item
        updatedItem.status = status
        updatedItem.updatedAt = Date()

        switch status {
        case .active:
            updatedItem.lastPurchasedAt = nil
        case .purchased:
            updatedItem.lastPurchasedAt = Date()
        case .removed:
            break
        }

        try await repository.updateItem(updatedItem)
        return updatedItem
    }

    func buildListSummaries(lists: [UserGroceryList], items: [UserGroceryListItem]) -> [GroceryListSummary] {
        let itemsByListId = Dictionary(grouping: items.filter { $0.status != .removed }, by: \.listId)

        return lists.map { list in
            let relevantItems = itemsByListId[list.id] ?? []
            return GroceryListSummary(
                list: list,
                itemCount: relevantItems.count,
                activeCount: relevantItems.filter { $0.status == .active }.count,
                purchasedCount: relevantItems.filter { $0.status == .purchased }.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.list.isDefault != rhs.list.isDefault {
                return lhs.list.isDefault && !rhs.list.isDefault
            }

            if lhs.list.updatedAt != rhs.list.updatedAt {
                return lhs.list.updatedAt > rhs.list.updatedAt
            }

            return lhs.list.title.localizedCaseInsensitiveCompare(rhs.list.title) == .orderedAscending
        }
    }

    func makeUpcomingSuggestions(from items: [UserGroceryListItem], limit: Int = 6) -> [ProductCatalogItem] {
        let activeProductIds = Set(items.filter { $0.status == .active }.compactMap(\.productCatalogId))
        let recentProductIds = items
            .filter { $0.status == .purchased }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap(\.productCatalogId)

        var suggestions: [ProductCatalogItem] = []
        var seenIds = Set<String>()

        for productId in recentProductIds {
            guard !activeProductIds.contains(productId),
                  !seenIds.contains(productId),
                  let product = catalogCache.first(where: { $0.id == productId }) else {
                continue
            }

            suggestions.append(product)
            seenIds.insert(productId)
            if suggestions.count == limit {
                return suggestions
            }
        }

        for product in catalogCache where !activeProductIds.contains(product.id) && !seenIds.contains(product.id) {
            suggestions.append(product)
            seenIds.insert(product.id)
            if suggestions.count == limit {
                break
            }
        }

        return suggestions
    }

    /// Aggiunge alla lista quello che l'utente ha detto o scritto, spezzando la
    /// frase in più articoli.
    ///
    /// "due litri di latte, il pane e sei uova" sono tre righe, non una. Il
    /// risultato restituito è quello dell'ultimo articolo, che è ciò che serve
    /// al riepilogo a schermo.
    func processVoiceItemAddition(userId: String, rawInputText: String) async throws -> (UserGroceryList, GroceryItemCreationResult) {
        let defaultList = try await ensureDefaultList(for: userId)
        let drafts = await GroceryIntelligentParser().parse(rawInputText)

        // Se il parser non capisce niente, si salva la frase così com'è: meglio
        // una riga da sistemare a mano che un articolo perso.
        let resolvedDrafts = drafts.isEmpty
            ? [GroceryItemDraft(rawInputText: rawInputText, quantity: 1, unit: nil, notes: nil)]
            : drafts.map(\.draft)

        var lastResult: GroceryItemCreationResult?

        for draft in resolvedDrafts {
            lastResult = try await createItemResult(listId: defaultList.id, userId: userId, draft: draft)
        }

        guard let lastResult else {
            throw NSError(
                domain: "SmartGroceryService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(
                    localized: "grocery.error.nothingToAdd",
                    defaultValue: "Non ho capito cosa aggiungere alla lista."
                )]
            )
        }

        return (defaultList, lastResult)
    }

    /// Inserimento veloce da testo libero: una riga per articolo, oppure una
    /// frase sola con tutto dentro.
    @discardableResult
    func addItems(fromText text: String, userId: String) async throws -> [UserGroceryListItem] {
        let drafts = await GroceryIntelligentParser().parse(text)
        guard !drafts.isEmpty else { return [] }

        let defaultList = try await ensureDefaultList(for: userId)

        var created: [UserGroceryListItem] = []
        for draft in drafts {
            created.append(try await createItem(listId: defaultList.id, userId: userId, draft: draft.draft))
        }

        return created
    }

    func reactivationSuggestionMessage(_ suggestion: GroceryReactivationSuggestion) -> String {
        if let lastPurchasedAt = suggestion.lastPurchasedAt {
            return "Ultimo acquisto \(SmartGroceryFormatters.relativeDate(lastPurchasedAt)). Lo hai terminato?"
        }

        return "Lo avevi gia segnato come acquistato. Vuoi riattivarlo nella lista?"
    }

    private func sanitizedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func makeReactivationSuggestion(
        for item: UserGroceryListItem,
        userId: String
    ) async throws -> GroceryReactivationSuggestion? {
        let historicalItems = try await repository.fetchAllItems(for: userId)

        let purchasedMatch = historicalItems
            .filter { historicalItem in
                historicalItem.id != item.id &&
                historicalItem.status == .purchased
            }
            .filter { historicalItem in
                if let productCatalogId = item.productCatalogId {
                    return historicalItem.productCatalogId == productCatalogId
                }

                return normalizeForHistory(historicalItem.displayName) == normalizeForHistory(item.displayName)
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.lastPurchasedAt ?? lhs.updatedAt
                let rhsDate = rhs.lastPurchasedAt ?? rhs.updatedAt
                return lhsDate > rhsDate
            }
            .first

        guard let purchasedMatch else {
            return nil
        }

        return GroceryReactivationSuggestion(
            id: "\(item.id)-\(purchasedMatch.id)",
            matchedProductName: item.displayName,
            previousItemName: purchasedMatch.displayName,
            lastPurchasedAt: purchasedMatch.lastPurchasedAt
        )
    }

    private func normalizeForHistory(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
