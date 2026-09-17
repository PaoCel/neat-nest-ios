import SwiftUI

struct SmartGrocerySpendingView: View {
    @State private var viewModel: SmartGrocerySpendingViewModel
    @State private var isPresentingImportSheet = false

    init(userSession: UserSession, viewModel: SmartGrocerySpendingViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SmartGrocerySpendingViewModel(userSession: userSession))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroSection
                importSection
                categorySection
                receiptsSection
                recentPurchasesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Spesa & storico")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Importa") {
                    isPresentingImportSheet = true
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $isPresentingImportSheet) {
            DemoReceiptImportSheet(viewModel: viewModel)
        }
        .alert("Smart Grocery", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var heroSection: some View {
        Group {
            if let summary = viewModel.summary, summary.totalSpend > 0 {
                SmartGroceryHeroCard(colors: [Color.orange, Color.red]) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Ultimi 30 giorni")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            SmartGroceryStatusBadge(title: "\(summary.receiptCount) scontrini", tint: .white)
                        }

                        Text("Spesa grocery sotto controllo")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(SmartGroceryFormatters.currency(summary.totalSpend))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Import demo receipt, riconciliazione leggera e breakdown per categoria in un solo spazio.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.92))

                        HStack(spacing: 10) {
                            SmartGroceryStatusBadge(
                                title: "Media \(SmartGroceryFormatters.currency(summary.averageBasket))",
                                tint: .white
                            )
                            SmartGroceryStatusBadge(
                                title: "Dal \(SmartGroceryFormatters.shortDate(summary.periodStart))",
                                tint: .white
                            )
                        }
                    }
                }
            } else {
                SmartGroceryHeroCard(colors: [Color.mint, Color.green]) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Expense tracker light")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            SmartGroceryStatusBadge(title: "Pronto per demo", tint: .white)
                        }

                        Text("Inizia con una demo receipt")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Importa uno scontrino strutturato e lascia che NeatNest lo trasformi in storico spese leggibile, con categorie e match al catalogo.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.92))

                        Button {
                            isPresentingImportSheet = true
                        } label: {
                            Text("Importa una demo receipt")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var importSection: some View {
        SmartGrocerySurface(tint: .orange) {
            SmartGrocerySectionHeader(
                title: "Import receipt",
                subtitle: "Scegli un modello locale, importa i line item e aggiorna subito storico e categorie."
            ) {
                Button("Apri demo") {
                    isPresentingImportSheet = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            }

            if let result = viewModel.lastImportResult {
                VStack(alignment: .leading, spacing: 14) {
                    importResultCard(result)

                    if let reconciliationHint = result.reconciliationHint {
                        reconciliationCard(reconciliationHint)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(viewModel.templates.prefix(3)) { template in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.retailerName)
                                .font(.subheadline.weight(.semibold))
                            Text(template.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Breakdown categorie",
                subtitle: "Una lettura immediata di dove sta andando la spesa grocery recente."
            ) {
                EmptyView()
            }

            if viewModel.isLoading && !viewModel.hasImportedReceipts {
                SmartGrocerySurface(tint: .orange) {
                    ProgressView("Sto caricando lo storico spesa...")
                        .tint(.orange)
                }
            } else if viewModel.categorySummaries.isEmpty {
                SmartGroceryEmptyStateCard(
                    icon: "chart.bar.xaxis",
                    title: "Ancora nessuna categoria",
                    message: "Importa la prima demo receipt per vedere il breakdown della spesa."
                )
            } else {
                SmartGrocerySurface(tint: .orange) {
                    VStack(spacing: 16) {
                        ForEach(viewModel.categorySummaries) { summary in
                            SpendingCategoryRow(summary: summary)
                        }
                    }
                }
            }
        }
    }

    private var receiptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Scontrini recenti",
                subtitle: "Un riepilogo pulito delle importazioni piu recenti."
            ) {
                EmptyView()
            }

            if viewModel.recentReceipts.isEmpty {
                SmartGroceryEmptyStateCard(
                    icon: "doc.text.magnifyingglass",
                    title: "Nessuno scontrino ancora importato",
                    message: "Dopo il primo import vedrai qui retailer, data e totale dei tuoi acquisti."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.recentReceipts) { receipt in
                            ReceiptSummaryCard(
                                receipt: receipt,
                                itemCount: itemCount(for: receipt)
                            )
                            .frame(width: 260)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var recentPurchasesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Acquisti recenti",
                subtitle: "Line item importati, con retailer, categoria e match al catalogo quando disponibile."
            ) {
                EmptyView()
            }

            if viewModel.recentPurchases.isEmpty {
                SmartGroceryEmptyStateCard(
                    icon: "cart",
                    title: "Storico acquisti vuoto",
                    message: "Importa una demo receipt per popolare subito questo storico."
                )
            } else {
                SmartGrocerySurface(tint: .mint) {
                    VStack(spacing: 14) {
                        ForEach(Array(viewModel.recentPurchases.prefix(8))) { entry in
                            PurchaseHistoryRow(entry: entry)
                        }
                    }
                }
            }
        }
    }

    private func itemCount(for receipt: ReceiptImport) -> Int {
        viewModel.recentPurchases.filter { $0.receipt.id == receipt.id }.count
    }

    private func importResultCard(_ result: ReceiptImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Importato da \(result.receipt.retailerName)")
                        .font(.headline)

                    Text("\(result.lineItems.count) line item, totale \(SmartGroceryFormatters.currency(result.receipt.totalAmount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Nascondi") {
                    viewModel.clearLastImportResult()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }

            HStack(spacing: 10) {
                SmartGroceryStatusBadge(title: "\(result.matchedLineCount) match al catalogo", tint: .green)
                if result.unresolvedLineCount > 0 {
                    SmartGroceryStatusBadge(title: "\(result.unresolvedLineCount) custom", tint: .orange)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private func reconciliationCard(_ hint: ReceiptReconciliationHint) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 8) {
                Text(hint.title)
                    .font(.headline)

                Text(hint.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct DemoReceiptImportSheet: View {
    @Bindable var viewModel: SmartGrocerySpendingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SmartGroceryHeroCard(colors: [Color.orange, Color.pink]) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Import demo receipt")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Text("Scegli un modello e aggiorna subito lo storico")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Ogni import costruisce receipt, line item, categorie e hint di riconciliazione.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }

                    ForEach(viewModel.templates) { template in
                        Button {
                            _Concurrency.Task {
                                await viewModel.importTemplate(template)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            DemoReceiptTemplateCard(
                                template: template,
                                isImporting: viewModel.isImporting
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isImporting)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Demo receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DemoReceiptTemplateCard: View {
    let template: DemoReceiptTemplate
    let isImporting: Bool

    var body: some View {
        SmartGrocerySurface(tint: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.retailerName)
                            .font(.headline)

                        Text(template.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    SmartGroceryStatusBadge(title: SmartGroceryFormatters.currency(template.estimatedTotal), tint: accentColor)
                }

                Text(SmartGroceryFormatters.shortDate(template.purchaseDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(template.previewLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                    }
                }

                HStack {
                    Text("\(template.lineItems.count) line item")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if isImporting {
                        ProgressView()
                            .tint(accentColor)
                    } else {
                        Text("Importa")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
    }

    private var accentColor: Color {
        switch template.accentColorName {
        case "blue":
            return .blue
        case "orange":
            return .orange
        default:
            return .green
        }
    }
}

private struct SpendingCategoryRow: View {
    let summary: GrocerySpendingCategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: summary.category.iconName)
                        .foregroundStyle(summary.category.tintColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.category.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(summary.itemCount) line item")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(SmartGroceryFormatters.currency(summary.amount))
                        .font(.subheadline.weight(.semibold))
                    Text(SmartGroceryFormatters.percentLabel(summary.share))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(summary.category.tintColor.opacity(0.14))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(summary.category.tintColor)
                            .frame(width: max(proxy.size.width * summary.share, 14))
                    }
            }
            .frame(height: 10)
        }
    }
}

private struct ReceiptSummaryCard: View {
    let receipt: ReceiptImport
    let itemCount: Int

    var body: some View {
        SmartGrocerySurface(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(receipt.retailerName)
                        .font(.headline)

                    Spacer()

                    SmartGroceryStatusBadge(title: receipt.sourceType.localizedTitle, tint: .orange)
                }

                Text(SmartGroceryFormatters.currency(receipt.totalAmount, currencyCode: receipt.currency))
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(SmartGroceryFormatters.shortDate(receipt.purchaseDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(itemCount) acquisti importati")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PurchaseHistoryRow: View {
    let entry: PurchaseHistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: entry.lineItem.inferredCategory.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(entry.lineItem.inferredCategory.tintColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(entry.lineItem.inferredCategory.tintColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.lineItem.displayName)
                            .font(.subheadline.weight(.semibold))

                        Text("\(entry.receipt.retailerName) • \(SmartGroceryFormatters.shortDate(entry.receipt.purchaseDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(SmartGroceryFormatters.currency(entry.lineItem.lineTotal, currencyCode: entry.receipt.currency))
                        .font(.subheadline.weight(.semibold))
                }

                HStack(spacing: 8) {
                    SmartGroceryStatusBadge(title: entry.lineItem.inferredCategory.localizedTitle, tint: entry.lineItem.inferredCategory.tintColor)
                    if entry.lineItem.productCatalogId != nil {
                        SmartGroceryStatusBadge(title: "Catalogo", tint: .green)
                    } else {
                        SmartGroceryStatusBadge(title: "Custom", tint: .gray)
                    }
                }
            }
        }
    }
}

@MainActor
private struct SmartGrocerySpendingViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()

    var body: some View {
        NavigationStack {
            SmartGrocerySpendingView(
                userSession: session,
                viewModel: PreviewSupport.makeSmartGrocerySpendingViewModel()
            )
        }
    }
}

#Preview("Smart Grocery Spending") {
    SmartGrocerySpendingViewPreviewContainer()
}
