import Foundation

@MainActor
final class ReceiptImportService {
    private let expenseRepository: GroceryExpenseRepository
    private let groceryRepository: SmartGroceryRepository
    private let groceryService: SmartGroceryService
    private let demoReceiptProvider: DemoReceiptProvider
    private let categoryInferrer: ReceiptCategoryInferrer
    private let observationRepository: PriceObservationRepository

    init(
        expenseRepository: GroceryExpenseRepository = GroceryExpenseRepository(),
        groceryRepository: SmartGroceryRepository = SmartGroceryRepository(),
        demoReceiptProvider: DemoReceiptProvider = SeededDemoReceiptProvider(),
        categoryInferrer: ReceiptCategoryInferrer = ReceiptCategoryInferrer(),
        observationRepository: PriceObservationRepository = PriceObservationRepository()
    ) {
        self.expenseRepository = expenseRepository
        self.groceryRepository = groceryRepository
        self.groceryService = SmartGroceryService(repository: groceryRepository)
        self.demoReceiptProvider = demoReceiptProvider
        self.categoryInferrer = categoryInferrer
        self.observationRepository = observationRepository
    }

    func loadTemplates() async throws -> [DemoReceiptTemplate] {
        let templates = try await demoReceiptProvider.loadTemplates()
        return templates.sorted { $0.purchaseDate > $1.purchaseDate }
    }

    /// Porta in NeatNest uno scontrino letto dalla fotocamera.
    ///
    /// Stessa strada dell'import demo: match sul catalogo prodotti, categoria
    /// inferita, riconciliazione con le liste della spesa. Cambia solo da dove
    /// arrivano le righe.
    func importScannedReceipt(_ parsed: ParsedReceipt, userId: String) async throws -> ReceiptImportResult {
        guard !parsed.lines.isEmpty else { throw ReceiptScannerError.noTextFound }

        _ = await groceryService.prepareCatalog()

        let receiptImport = ReceiptImport(
            userId: userId,
            retailerName: parsed.retailerName ?? String(
                localized: "receipt.scan.unknownRetailer",
                defaultValue: "Negozio non riconosciuto"
            ),
            purchaseDate: parsed.purchaseDate ?? Date(),
            totalAmount: parsed.declaredTotal ?? parsed.computedTotal,
            sourceType: .scanned
        )

        let lineItems = parsed.lines.map { line in
            makeLineItem(
                rawLineText: line.rawText,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                lineTotal: line.lineTotal,
                receiptImportId: receiptImport.id,
                userId: userId
            )
        }

        try await expenseRepository.createReceiptImport(receiptImport, lineItems: lineItems)

        // Ogni riga è anche un prezzo visto in un negozio in un giorno. È da qui
        // che nasce il listino della community. Se fallisce, l'import resta
        // valido: i prezzi sono un di più, non il motivo per cui l'utente è qui.
        await recordObservations(from: lineItems, receipt: receiptImport)

        let reconciliationHint = try await buildReconciliationHint(for: lineItems, userId: userId)

        return ReceiptImportResult(
            receipt: receiptImport,
            lineItems: lineItems,
            matchedLineCount: lineItems.filter { $0.productCatalogId != nil }.count,
            unresolvedLineCount: lineItems.filter { $0.productCatalogId == nil }.count,
            reconciliationHint: reconciliationHint
        )
    }

    func importTemplate(_ template: DemoReceiptTemplate, userId: String) async throws -> ReceiptImportResult {
        _ = await groceryService.prepareCatalog()

        let receiptImport = ReceiptImport(
            userId: userId,
            retailerName: template.retailerName,
            purchaseDate: template.purchaseDate,
            totalAmount: template.estimatedTotal,
            currency: template.currency,
            sourceType: .demo
        )

        let lineItems = template.lineItems.map { line in
            makeLineItem(from: line, receiptImportId: receiptImport.id, userId: userId)
        }

        try await expenseRepository.createReceiptImport(receiptImport, lineItems: lineItems)

        let reconciliationHint = try await buildReconciliationHint(for: lineItems, userId: userId)

        return ReceiptImportResult(
            receipt: receiptImport,
            lineItems: lineItems,
            matchedLineCount: lineItems.filter { $0.productCatalogId != nil }.count,
            unresolvedLineCount: lineItems.filter { $0.productCatalogId == nil }.count,
            reconciliationHint: reconciliationHint
        )
    }
}

private extension ReceiptImportService {
    /// Le demo receipt non contribuiscono: sono dati inventati e sporcherebbero
    /// il listino reale.
    func recordObservations(from lineItems: [ReceiptLineItem], receipt: ReceiptImport) async {
        guard receipt.sourceType == .scanned else { return }

        let retailerId = Self.retailerSlug(from: receipt.retailerName)
        guard !retailerId.isEmpty else { return }

        let observations = lineItems.compactMap { line -> PriceObservation? in
            guard let productCatalogId = line.productCatalogId else { return nil }

            let quantity = max(1, line.quantity ?? 1)
            let unitPrice = line.unitPrice ?? (line.lineTotal / quantity)
            guard unitPrice > 0 else { return nil }

            return PriceObservation(
                retailerId: retailerId,
                productCatalogId: productCatalogId,
                rawLabel: line.rawLineText,
                price: unitPrice,
                currency: receipt.currency,
                observedAt: receipt.purchaseDate,
                source: .receipt
            )
        }

        try? await observationRepository.record(observations)
    }

    /// Un identificativo stabile per l'insegna, anche quando non è in anagrafica:
    /// il minimarket sotto casa deve poter contribuire come Esselunga.
    static func retailerSlug(from name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        let allowed = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }

        return String(allowed)
            .split(separator: "-")
            .prefix(4)
            .joined(separator: "-")
    }

    func makeLineItem(
        from templateLine: DemoReceiptTemplateLine,
        receiptImportId: String,
        userId: String
    ) -> ReceiptLineItem {
        makeLineItem(
            rawLineText: templateLine.rawLineText,
            quantity: templateLine.quantity,
            unitPrice: templateLine.unitPrice,
            lineTotal: templateLine.lineTotal,
            receiptImportId: receiptImportId,
            userId: userId
        )
    }

    func makeLineItem(
        rawLineText: String,
        quantity: Double?,
        unitPrice: Double?,
        lineTotal: Double,
        receiptImportId: String,
        userId: String
    ) -> ReceiptLineItem {
        let match = groceryService.match(rawInputText: rawLineText)
        let inferred = categoryInferrer.inferCategory(
            rawLineText: rawLineText,
            matchedProduct: match?.product
        )

        return ReceiptLineItem(
            receiptImportId: receiptImportId,
            userId: userId,
            rawLineText: rawLineText,
            normalizedName: match?.product.canonicalName ?? normalizedReceiptName(from: rawLineText),
            productCatalogId: match?.product.id,
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
            inferredCategory: inferred.category,
            confidence: inferred.confidence
        )
    }

    func buildReconciliationHint(
        for lineItems: [ReceiptLineItem],
        userId: String
    ) async throws -> ReceiptReconciliationHint? {
        let lists = try await groceryRepository.fetchLists(for: userId)
        let activeItems = try await groceryRepository.fetchAllItems(for: userId)
            .filter { $0.status == .active }

        guard !lists.isEmpty, !activeItems.isEmpty else {
            return nil
        }

        let listsById = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0.title) })
        var matchedItemIds = Set<String>()
        var matchedListTitles = Set<String>()

        for lineItem in lineItems {
            let matchingItems = activeItems.filter { candidate in
                if let productCatalogId = lineItem.productCatalogId {
                    return candidate.productCatalogId == productCatalogId
                }

                let candidateText = normalizeForComparison(candidate.displayName)
                let candidateRawText = normalizeForComparison(candidate.rawInputText)
                let importedText = normalizeForComparison(lineItem.displayName)
                return candidateText == importedText || candidateRawText == importedText
            }

            for matchingItem in matchingItems {
                matchedItemIds.insert(matchingItem.id)
                if let listTitle = listsById[matchingItem.listId] {
                    matchedListTitles.insert(listTitle)
                }
            }
        }

        guard !matchedItemIds.isEmpty else {
            return nil
        }

        return ReceiptReconciliationHint(
            matchedItemCount: matchedItemIds.count,
            listTitles: matchedListTitles.sorted()
        )
    }

    func normalizedReceiptName(from rawLineText: String) -> String {
        rawLineText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
            .localizedCapitalized
    }

    func normalizeForComparison(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
