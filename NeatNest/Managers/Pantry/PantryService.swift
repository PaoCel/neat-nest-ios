import Foundation

/// Cosa succede a una riga dello scontrino quando entra in dispensa.
enum PantryIngestionKind: Hashable, Sendable {
    /// Crea una riga nuova.
    case new
    /// Si somma a una riga già presente in dispensa.
    case merge(existingItemId: String)

    var isMerge: Bool {
        if case .merge = self { return true }
        return false
    }
}

/// Una riga dello scontrino tradotta in proposta per la dispensa, ancora modificabile.
struct PantryIngestionCandidate: Identifiable, Hashable {
    let id: String
    var item: PantryItem
    let kind: PantryIngestionKind
    let rawLineText: String
    /// Lo scontrino non ha detto abbastanza: nessun match nel catalogo prodotti.
    /// È il caso "ARTICOLO 1, cosa è?" da far risolvere all'utente.
    let needsReview: Bool
    var isIncluded: Bool

    init(
        id: String = UUID().uuidString,
        item: PantryItem,
        kind: PantryIngestionKind,
        rawLineText: String,
        needsReview: Bool,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.item = item
        self.kind = kind
        self.rawLineText = rawLineText
        self.needsReview = needsReview
        self.isIncluded = isIncluded
    }
}

/// Cosa lo scontrino propone di mettere in dispensa, prima che l'utente confermi.
struct PantryIngestionPlan {
    var candidates: [PantryIngestionCandidate]
    /// Righe scartate perché non alimentari o illeggibili.
    var skippedLineTexts: [String]

    var includedCandidates: [PantryIngestionCandidate] {
        candidates.filter(\.isIncluded)
    }

    var reviewCount: Int {
        candidates.filter { $0.needsReview && $0.isIncluded }.count
    }

    var isEmpty: Bool { candidates.isEmpty }
}

/// Logica di dominio della dispensa: creare, fondere, consumare, importare.
///
/// Il servizio non conosce la UI e non formatta niente: restituisce modelli.
final class PantryService {
    private let repository: PantryRepository
    private let locale: Locale
    private let calendar: Calendar

    init(
        repository: PantryRepository = PantryRepository(),
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.locale = locale
        self.calendar = calendar
    }

    // MARK: - Creazione

    /// Costruisce una riga di dispensa completando ciò che l'utente non ha detto:
    /// dove va conservata e quando scade.
    func makeItem(
        userId: String,
        name: String,
        quantity: PantryQuantity,
        category: GrocerySpendingCategory,
        storage: PantryStorage? = nil,
        expiresAt: Date? = nil,
        openedAt: Date? = nil,
        productCatalogId: String? = nil,
        brand: String? = nil,
        source: PantrySource = .manual,
        sourceReferenceId: String? = nil,
        notes: String? = nil,
        referenceDate: Date = Date()
    ) throws -> PantryItem {
        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else { throw PantryError.emptyName }
        guard quantity.value > 0 else { throw PantryError.invalidQuantity }

        // Chi scrive "Ricotta 250g" e lascia "1 pezzo" intende 250 g: si legge
        // la pezzatura invece di costringerlo a cambiare unità.
        var resolvedQuantity = quantity
        if quantity.unit == .piece, let size = PackageSizeParser.parse(trimmedName) {
            let total = size.totalQuantity
            resolvedQuantity = PantryQuantity(value: total.value * quantity.value, unit: total.unit)
        }

        let resolvedStorage = storage ?? PantryStorage.suggested(for: category)
        let estimated = expiresAt == nil
            ? ShelfLifeCatalog.estimatedExpiry(
                productName: trimmedName,
                category: category,
                storage: resolvedStorage,
                referenceDate: referenceDate,
                openedAt: openedAt,
                locale: locale,
                calendar: calendar
            )
            : nil

        return PantryItem(
            userId: userId,
            productCatalogId: productCatalogId,
            name: LocalizedContent(source: trimmedName),
            brand: brand,
            quantity: resolvedQuantity,
            initialQuantity: resolvedQuantity,
            level: openedAt == nil ? .sealed : .plenty,
            storage: resolvedStorage,
            category: category,
            addedAt: referenceDate,
            openedAt: openedAt,
            expiresAt: expiresAt ?? estimated,
            isExpiryEstimated: expiresAt == nil && estimated != nil,
            source: source,
            sourceReferenceId: sourceReferenceId,
            notes: notes,
            updatedAt: referenceDate
        )
    }

    func add(_ item: PantryItem) async throws {
        try await repository.save(item)
    }

    func update(_ item: PantryItem, referenceDate: Date = Date()) async throws {
        var updated = item
        updated.updatedAt = referenceDate
        try await repository.save(updated)
    }

    func remove(_ item: PantryItem) async throws {
        try await repository.delete(itemId: item.id)
    }

    // MARK: - Uso quotidiano

    /// Segna il prodotto come aperto e ricalcola la scadenza sulla vita "da aperto".
    func markOpened(_ item: PantryItem, on date: Date = Date()) async throws -> PantryItem {
        var updated = item
        updated.openedAt = date
        updated.updatedAt = date

        if updated.level == .sealed {
            updated.level = .plenty
        }

        if item.isExpiryEstimated || item.expiresAt == nil {
            let estimate = ShelfLifeCatalog.estimatedExpiry(
                productName: item.displayName,
                category: item.category,
                storage: item.storage,
                referenceDate: date,
                openedAt: date,
                locale: locale,
                calendar: calendar
            )

            // Aprire un prodotto può solo accorciarne la vita, mai allungarla.
            if let estimate {
                updated.expiresAt = [estimate, item.expiresAt].compactMap { $0 }.min()
                updated.isExpiryEstimated = true
            }
        }

        try await repository.save(updated)
        return updated
    }

    /// Registra lo stato dichiarato dall'utente con un tap.
    ///
    /// "Finito" toglie il prodotto dalla dispensa: tenerlo a zero sarebbe solo
    /// una riga morta da scorrere.
    @discardableResult
    func setLevel(_ level: PantryLevel, for item: PantryItem, on date: Date = Date()) async throws -> PantryItem? {
        guard level != .finished else {
            try await repository.delete(itemId: item.id)
            return nil
        }

        let updated = item.settingLevel(level, on: date)
        try await repository.save(updated)
        return updated
    }

    /// Consuma una quantità. Se non resta niente la riga viene eliminata.
    @discardableResult
    func consume(_ item: PantryItem, amount: PantryQuantity, on date: Date = Date()) async throws -> PantryItem? {
        guard let remaining = item.quantity.subtracting(amount) else {
            throw PantryError.invalidQuantity
        }

        if remaining.isEmpty {
            try await repository.delete(itemId: item.id)
            return nil
        }

        var updated = item
        updated.quantity = remaining
        updated.updatedAt = date
        // Dedotta da una ricetta, non misurata: la fiducia scende a ogni passo.
        updated.quantityConfidence = max(0.3, item.quantityConfidence - 0.2)
        updated.openedAt = item.openedAt ?? date
        updated = updated.syncingLevelToQuantity()

        try await repository.save(updated)
        return updated
    }

    // MARK: - Import da scontrino

    /// Trasforma le righe di uno scontrino in proposte per la dispensa, fondendo
    /// con quello che c'è già. Non scrive niente: la conferma è dell'utente.
    func makeIngestionPlan(
        lineItems: [ReceiptLineItem],
        existingItems: [PantryItem],
        userId: String,
        purchaseDate: Date,
        receiptImportId: String?
    ) -> PantryIngestionPlan {
        var candidates: [PantryIngestionCandidate] = []
        var skipped: [String] = []

        for line in lineItems {
            let name = line.normalizedName.trimmed.isEmpty ? line.rawLineText.trimmed : line.normalizedName.trimmed
            guard !name.isEmpty else {
                skipped.append(line.rawLineText)
                continue
            }

            let profile = ShelfLifeCatalog.profile(
                forProductNamed: name,
                category: line.inferredCategory,
                locale: locale
            )

            guard profile != .nonFood else {
                skipped.append(line.rawLineText)
                continue
            }

            // "RICOTTA 250G" comprata in 2 copie fa 500 g, non 2 pezzi: è ciò
            // che rende confrontabile la dispensa con le ricette.
            let quantity = PackageSizeParser.quantity(
                forLineText: line.rawLineText,
                receiptQuantity: line.quantity ?? 1
            )

            guard let proposal = try? makeItem(
                userId: userId,
                name: name,
                quantity: quantity,
                category: line.inferredCategory,
                productCatalogId: line.productCatalogId,
                source: .receipt,
                sourceReferenceId: receiptImportId ?? line.receiptImportId,
                referenceDate: purchaseDate
            ) else {
                skipped.append(line.rawLineText)
                continue
            }

            // Lo stesso prodotto due volte sullo scontrino non deve produrre due righe.
            if let index = candidates.firstIndex(where: { $0.item.canMerge(with: proposal) }),
               let summed = candidates[index].item.quantity.adding(proposal.quantity) {
                candidates[index].item.quantity = summed
                continue
            }

            if let match = existingItems.first(where: { $0.canMerge(with: proposal) }),
               let summed = match.quantity.adding(proposal.quantity) {
                var merged = match
                merged.quantity = summed
                merged.updatedAt = purchaseDate
                // Fondendo due lotti, vale la scadenza più vicina.
                merged.expiresAt = [match.expiresAt, proposal.expiresAt].compactMap { $0 }.min()

                candidates.append(
                    PantryIngestionCandidate(
                        item: merged,
                        kind: .merge(existingItemId: match.id),
                        rawLineText: line.rawLineText,
                        needsReview: false
                    )
                )
                continue
            }

            candidates.append(
                PantryIngestionCandidate(
                    item: proposal,
                    kind: .new,
                    rawLineText: line.rawLineText,
                    needsReview: line.productCatalogId == nil
                )
            )
        }

        return PantryIngestionPlan(candidates: candidates, skippedLineTexts: skipped)
    }

    /// Scrive in dispensa solo i candidati che l'utente ha lasciato spuntati.
    func apply(_ plan: PantryIngestionPlan) async throws {
        let items = plan.includedCandidates.map(\.item)
        guard !items.isEmpty else { return }
        try await repository.save(items)
    }
}
