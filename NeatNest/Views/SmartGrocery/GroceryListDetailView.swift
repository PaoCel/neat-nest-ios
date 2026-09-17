import SwiftUI

struct GroceryListDetailView: View {
    let list: UserGroceryList

    @EnvironmentObject private var voiceManager: SmartGroceryVoiceManager
    private let userSession: UserSession
    @State private var viewModel: GroceryListDetailViewModel

    @State private var isPresentingAddSheet = false
    @State private var addDraft = GroceryItemDraft.empty
    @State private var editingItem: UserGroceryListItem?

    init(list: UserGroceryList, userSession: UserSession, viewModel: GroceryListDetailViewModel? = nil) {
        self.list = list
        self.userSession = userSession
        _viewModel = State(initialValue: viewModel ?? GroceryListDetailViewModel(list: list, userSession: userSession))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summarySection
                shortcutsSection
                insightsSection

                if viewModel.isLoading && viewModel.totalVisibleItems == 0 {
                    SmartGrocerySurface(tint: .green) {
                        ProgressView("Sto caricando gli articoli...")
                            .tint(.green)
                    }
                } else if viewModel.totalVisibleItems == 0 {
                    emptyStateSection
                } else {
                    itemSections
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addDraft = .empty
                    isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.large)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                addDraft = .empty
                isPresentingAddSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)

                    Text("Aggiungi articolo")
                        .font(.headline)
                }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.thinMaterial)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            GroceryItemEditorSheet(
                title: "Aggiungi articolo",
                initialDraft: addDraft,
                matchProvider: viewModel.previewMatch(for:)
            ) { draft in
                await viewModel.addItem(draft: draft)
            }
        }
        .sheet(item: $editingItem) { item in
            GroceryItemEditorSheet(
                title: "Modifica articolo",
                initialDraft: GroceryItemDraft(
                    rawInputText: item.rawInputText,
                    quantity: item.quantity,
                    unit: item.unit,
                    notes: item.notes
                ),
                matchProvider: viewModel.previewMatch(for:)
            ) { draft in
                await viewModel.updateItem(item, draft: draft)
            }
        }
        .alert("Smart Grocery", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var summarySection: some View {
        SmartGrocerySurface(tint: .green) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(list.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if list.isDefault {
                        SmartGroceryStatusBadge(title: "Principale", tint: .green)
                    }
                }

                Text(listSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    SmartGroceryStatusBadge(title: "\(viewModel.activeItems.count) da comprare", tint: .green)
                    SmartGroceryStatusBadge(title: "\(viewModel.purchasedItems.count) acquistati", tint: .blue)
                    if !viewModel.removedItems.isEmpty {
                        SmartGroceryStatusBadge(title: "\(viewModel.removedItems.count) rimossi", tint: .gray)
                    }
                }
            }
        }
    }

    private var shortcutsSection: some View {
        SmartGrocerySurface(tint: .mint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Azioni rapide")
                            .font(.headline)

                        Text("Siri resta un aiuto secondario. Il piano spesa deve vedersi subito.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                }

                NavigationLink(destination: LetsShopPreferenceView(list: list, userSession: userSession)) {
                    letsShopButton
                }
                .buttonStyle(.plain)
                .disabled(viewModel.activeItems.isEmpty)
                .opacity(viewModel.activeItems.isEmpty ? 0.55 : 1)
            }
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if let currentVoiceResult, currentVoiceResult.listId == list.id {
            voiceAddedCard(currentVoiceResult)
        }

        if let latestSuggestion = currentSuggestion {
            suggestionCard(latestSuggestion)
        }
    }

    private var emptyStateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGroceryEmptyStateCard(
                icon: "cart.badge.plus",
                title: "Lista ancora vuota",
                message: "Aggiungi articoli manualmente o usa uno dei suggerimenti dal catalogo per iniziare subito la demo."
            )

            SmartGrocerySurface(tint: .green) {
                SmartGrocerySectionHeader(
                    title: "Suggerimenti rapidi",
                    subtitle: "Tocca un prodotto per precompilare l'aggiunta."
                ) {
                    EmptyView()
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(viewModel.catalogSuggestions, id: \.id) { product in
                        Button {
                            addDraft = GroceryItemDraft(
                                rawInputText: product.canonicalName,
                                quantity: 1,
                                unit: nil,
                                notes: nil
                            )
                            isPresentingAddSheet = true
                        } label: {
                            SmartGrocerySuggestionChip(item: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var itemSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !viewModel.activeItems.isEmpty {
                section(title: "Da comprare", subtitle: nil, items: viewModel.activeItems)
            }

            if !viewModel.purchasedItems.isEmpty {
                section(title: "Acquistati", subtitle: nil, items: viewModel.purchasedItems)
            }

            if !viewModel.removedItems.isEmpty {
                section(title: "Rimossi", subtitle: nil, items: viewModel.removedItems)
            }
        }
    }

    private func section(title: String, subtitle: String?, items: [UserGroceryListItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SmartGrocerySectionHeader(title: title, subtitle: subtitle) {
                SmartGroceryStatusBadge(title: "\(items.count)", tint: Color.primary)
            }

            SmartGrocerySurface(tint: items.first?.status.rowTintColor ?? .green) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        GroceryListItemRow(
                            item: item,
                            onTogglePurchased: { viewModel.togglePurchased(item) },
                            onIncrease: { viewModel.adjustQuantity(for: item, delta: 1) },
                            onDecrease: { viewModel.adjustQuantity(for: item, delta: -1) },
                            onEdit: { editingItem = item },
                            onRemove: { viewModel.removeItem(item) },
                            onRestore: { viewModel.restoreItem(item) }
                        )

                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                                .padding(.vertical, 14)
                        }
                    }
                }
            }
        }
    }

    private var letsShopButton: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Facciamo la spesa")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(
                    viewModel.activeItems.isEmpty
                    ? "Aggiungi prima qualche articolo alla lista."
                    : "Confronta retailer, costi stimati e piano ottimizzato."
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .foregroundStyle(.white)
    }

    private var listSummaryText: String {
        if viewModel.totalVisibleItems == 0 {
            return "Lista vuota, pronta per iniziare."
        }

        if viewModel.purchasedItems.isEmpty {
            return "\(viewModel.activeItems.count) articoli ancora da comprare."
        }

        return "\(viewModel.activeItems.count) articoli ancora da comprare, \(viewModel.purchasedItems.count) gia segnati."
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

    private func voiceAddedCard(_ result: SmartGroceryVoiceProcessedResult) -> some View {
        SmartGrocerySurface(tint: .indigo) {
            SmartGrocerySectionHeader(
                title: "Aggiunto con Siri",
                subtitle: "L'ultimo comando vocale e stato elaborato sulla tua lista principale."
            ) {
                Button("Nascondi") {
                    voiceManager.clearLastProcessedResult()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(result.itemName)
                    .font(.headline)

                if result.itemName != result.rawInputText {
                    Text(result.rawInputText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SmartGroceryStatusBadge(
                    title: "Elaborato \(SmartGroceryFormatters.relativeDate(result.createdAt))",
                    tint: .primary
                )
            }
        }
    }

    private func suggestionCard(_ suggestion: GroceryReactivationSuggestion) -> some View {
        SmartGrocerySurface(tint: .orange) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(suggestion.title)
                            .font(.headline)

                        Spacer()

                        Button("Nascondi") {
                            if currentVoiceResult?.suggestion == suggestion {
                                voiceManager.clearLastProcessedResult()
                            } else {
                                viewModel.clearLatestSuggestion()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    }

                    Text(viewModelSuggestionMessage(for: suggestion))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SmartGroceryStatusBadge(title: "Suggerimento leggero", tint: .orange)
                }
            }
        }
    }

    private var currentVoiceResult: SmartGroceryVoiceProcessedResult? {
        voiceManager.lastProcessedResult
    }

    private var currentSuggestion: GroceryReactivationSuggestion? {
        if let voiceSuggestion = currentVoiceResult?.suggestion, currentVoiceResult?.listId == list.id {
            return voiceSuggestion
        }

        return viewModel.latestSuggestion
    }

    private func viewModelSuggestionMessage(for suggestion: GroceryReactivationSuggestion) -> String {
        if let lastPurchasedAt = suggestion.lastPurchasedAt {
            return "Ultimo acquisto \(SmartGroceryFormatters.relativeDate(lastPurchasedAt)). Lo hai terminato? Vuoi riattivarlo nella lista?"
        }

        return "Lo avevi gia comprato in passato. Vuoi riattivarlo nella lista?"
    }
}

private struct GroceryListItemRow: View {
    let item: UserGroceryListItem
    let onTogglePurchased: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onTogglePurchased) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tintColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(item.status == .removed)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .strikethrough(item.status == .purchased)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    Menu {
                        Button("Modifica") {
                            onEdit()
                        }

                        if item.status == .removed {
                            Button("Ripristina") {
                                onRestore()
                            }
                        } else {
                            Button(item.status == .purchased ? "Segna come attivo" : "Segna come acquistato") {
                                onTogglePurchased()
                            }

                            Button("Rimuovi", role: .destructive) {
                                onRemove()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                }

                HStack(spacing: 8) {
                    SmartGroceryStatusBadge(
                        title: SmartGroceryFormatters.quantityLabel(quantity: item.quantity, unit: item.unit),
                        tint: .primary
                    )
                    SmartGroceryStatusBadge(
                        title: item.effectiveEnrichmentStatus.localizedTitle,
                        tint: item.effectiveEnrichmentStatus.tintColor
                    )
                    if item.status == .removed {
                        SmartGroceryStatusBadge(title: "Rimosso", tint: .gray)
                    }
                }

                if item.isResolved && item.displayName != item.rawInputText {
                    Text("Originale: \(item.rawInputText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.effectiveEnrichmentStatus.isPending {
                    Text("Sto cercando un match reale per usarlo nel catalogo e nelle prossime raccomandazioni.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .center, spacing: 10) {
                    if item.status == .purchased, let lastPurchasedAt = item.lastPurchasedAt {
                        Text("Acquistato \(SmartGroceryFormatters.relativeDate(lastPurchasedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if item.status != .removed {
                        HStack(spacing: 10) {
                            smallQuantityButton(icon: "minus", action: onDecrease)
                            Text(SmartGroceryFormatters.quantityLabel(quantity: item.quantity, unit: item.unit))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(minWidth: 52)
                            smallQuantityButton(icon: "plus", action: onIncrease)
                        }
                    }
                }
            }
        }
    }

    private var leadingIcon: String {
        switch item.status {
        case .active:
            return "circle"
        case .purchased:
            return "checkmark.circle.fill"
        case .removed:
            return "minus.circle.fill"
        }
    }

    private var tintColor: Color {
        switch item.status {
        case .active:
            return .green
        case .purchased:
            return .blue
        case .removed:
            return .red
        }
    }

    private func smallQuantityButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GroceryItemEditorSheet: View {
    let title: String
    let matchProvider: (String) -> GroceryCatalogMatch?
    let onSave: (GroceryItemDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rawInputText: String
    @State private var quantityText: String
    @State private var selectedUnit: String
    @State private var notes: String
    @State private var isSaving = false

    init(
        title: String,
        initialDraft: GroceryItemDraft,
        matchProvider: @escaping (String) -> GroceryCatalogMatch?,
        onSave: @escaping (GroceryItemDraft) async -> Bool
    ) {
        self.title = title
        self.matchProvider = matchProvider
        self.onSave = onSave
        _rawInputText = State(initialValue: initialDraft.rawInputText)
        _quantityText = State(initialValue: SmartGroceryFormatters.quantityLabel(quantity: initialDraft.quantity, unit: nil))
        _selectedUnit = State(initialValue: initialDraft.unit ?? "")
        _notes = State(initialValue: initialDraft.notes ?? "")
    }

    private let unitOptions = ["", "pz", "kg", "g", "L", "ml", "conf."]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SmartGrocerySurface(tint: .green) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Articolo")
                                .font(.headline)

                            TextField("Esempio: latte Arborea", text: $rawInputText, axis: .vertical)
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                )
                        }
                    }

                    SmartGrocerySurface(tint: .mint) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Dettagli")
                                .font(.headline)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quantita")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("1", text: $quantityText)
                                        .keyboardType(.decimalPad)
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                        )
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Unita")
                                        .font(.subheadline.weight(.semibold))

                                    Picker("Unita", selection: $selectedUnit) {
                                        Text("Nessuna").tag("")
                                        ForEach(unitOptions.filter { !$0.isEmpty }, id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    )
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note")
                                    .font(.subheadline.weight(.semibold))

                                TextField("Opzionale: marca, formato, promemoria...", text: $notes, axis: .vertical)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    )
                            }
                        }
                    }

                    SmartGroceryMatchPreviewCard(
                        rawInputText: rawInputText,
                        match: matchProvider(rawInputText)
                    )
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .tint(.green)
                    } else {
                        Button("Salva") {
                            _Concurrency.Task {
                                isSaving = true
                                let didSave = await onSave(currentDraft)
                                isSaving = false
                                if didSave {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(rawInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentDraft: GroceryItemDraft {
        GroceryItemDraft(
            rawInputText: rawInputText,
            quantity: parsedQuantity,
            unit: selectedUnit.isEmpty ? nil : selectedUnit,
            notes: notes
        )
    }

    private var parsedQuantity: Double {
        let normalized = quantityText.replacingOccurrences(of: ",", with: ".")
        return max(0.5, Double(normalized) ?? 1)
    }
}

private extension GroceryItemStatus {
    var rowTintColor: Color {
        switch self {
        case .active:
            return .green
        case .purchased:
            return .blue
        case .removed:
            return .red
        }
    }
}

@MainActor
private struct GroceryListDetailViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()
    private let voiceManager = PreviewSupport.makeVoiceManager()

    var body: some View {
        NavigationStack {
            GroceryListDetailView(
                list: PreviewSupport.defaultList,
                userSession: session,
                viewModel: PreviewSupport.makeGroceryListDetailViewModel()
            )
            .environmentObject(voiceManager)
        }
    }
}

#Preview("Shopping List Detail") {
    GroceryListDetailViewPreviewContainer()
}
