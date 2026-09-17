import SwiftUI

/// Punto d'ingresso della dispensa: risolve l'utente e poi mostra il contenuto.
struct PantryHomeView: View {
    let userSession: UserSession

    var body: some View {
        Group {
            if let userId = userSession.currentUserId, !userId.isEmpty {
                PantryContentView(userId: userId, viewModel: PantryHomeViewModel(userId: userId))
            } else {
                ContentUnavailableView(
                    "Accedi per usare la dispensa",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("La dispensa è legata al tuo account per poterla condividere con la famiglia.")
                )
            }
        }
        .navigationTitle("Dispensa")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct PantryContentView: View {
    let userId: String

    @State var viewModel: PantryHomeViewModel
    @State private var isPresentingEditor = false
    @State private var isPresentingImport = false
    @State private var itemPendingDeletion: PantryItem?
    @State private var showOnlyExpiring = false
    @State private var dismissedLevelChecks: Set<String> = []

    var body: some View {
        List {
            if let itemToCheck = pendingLevelCheck {
                Section {
                    PantryLevelPrompt(
                        item: itemToCheck,
                        onSelect: { level in
                            dismissedLevelChecks.insert(itemToCheck.id)
                            _Concurrency.Task { await viewModel.setLevel(level, for: itemToCheck) }
                        },
                        onDismiss: {
                            withAnimation { _ = dismissedLevelChecks.insert(itemToCheck.id) }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if !viewModel.repurchaseSuggestions.isEmpty && !showOnlyExpiring {
                Section {
                    ForEach(viewModel.repurchaseSuggestions.prefix(4)) { suggestion in
                        RepurchaseSuggestionRow(
                            suggestion: suggestion,
                            onAdd: {
                                _Concurrency.Task { await viewModel.addToShoppingList(suggestion) }
                            },
                            onDismiss: {
                                withAnimation { viewModel.dismissSuggestion(suggestion) }
                            }
                        )
                    }
                } header: {
                    Label("Di solito a quest'ora è finito", systemImage: "arrow.clockwise.circle")
                } footer: {
                    Text("Dedotto dai tuoi scontrini. Se sbaglia, scarta e non te lo richiede.")
                }
            }

            if !viewModel.expiringSoonItems.isEmpty && !showOnlyExpiring {
                Section {
                    PantryExpiringBanner(items: viewModel.expiringSoonItems) {
                        withAnimation { showOnlyExpiring = true }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if showOnlyExpiring {
                Section {
                    Button {
                        withAnimation { showOnlyExpiring = false }
                    } label: {
                        Label("Mostra tutta la dispensa", systemImage: "arrow.uturn.backward")
                    }
                }
            }

            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.items) { item in
                        PantryItemRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    itemPendingDeletion = item
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }

                                Button {
                                    _Concurrency.Task { await viewModel.consumeOne(item) }
                                } label: {
                                    Label("Usato", systemImage: "minus.circle")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                if !item.isOpened {
                                    Button {
                                        _Concurrency.Task { await viewModel.markOpened(item) }
                                    } label: {
                                        Label("Aperto", systemImage: "seal.badge")
                                    }
                                    .tint(.orange)
                                }
                            }
                            .contextMenu {
                                Section("Quanto ne resta?") {
                                    ForEach(PantryLevel.openedCases) { level in
                                        Button {
                                            _Concurrency.Task { await viewModel.setLevel(level, for: item) }
                                        } label: {
                                            Label {
                                                Text(level.title)
                                            } icon: {
                                                Image(systemName: level.icon)
                                            }
                                        }
                                    }
                                }
                            }
                    }
                } header: {
                    Label(section.title, systemImage: section.systemImage)
                }
            }

            if viewModel.isEmpty {
                emptyState
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !viewModel.isEmpty {
                VStack(spacing: 10) {
                    PantryStorageFilterBar(selection: $viewModel.storageFilter)

                    Picker("Raggruppa per", selection: $viewModel.grouping) {
                        ForEach(PantryGrouping.allCases) { grouping in
                            Text(grouping.title).tag(grouping)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: Text("Cerca in dispensa"))
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingImport = true
                } label: {
                    Label("Dallo scontrino", systemImage: "doc.text.viewfinder")
                }
                .accessibilityHint(Text("Porta in dispensa i prodotti di uno scontrino importato"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingEditor = true
                } label: {
                    Label("Aggiungi prodotto", systemImage: "plus")
                }
                .accessibilityHint(Text("Apre la scheda per aggiungere un prodotto in dispensa"))
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            PantryItemEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $isPresentingImport) {
            PantryImportReviewView(viewModel: PantryImportViewModel(userId: userId))
        }
        .alert(
            "Eliminare il prodotto?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            presenting: itemPendingDeletion
        ) { item in
            Button("Elimina", role: .destructive) {
                _Concurrency.Task { await viewModel.delete(item) }
            }
            Button("Annulla", role: .cancel) { }
        } message: { item in
            Text("\(item.displayName) verrà rimosso dalla dispensa.")
        }
        .alert(
            "Dispensa",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("Riprova") { viewModel.retry() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.start()
            await viewModel.loadRepurchaseSuggestions()
        }
    }

    /// Si chiede di un prodotto solo, e solo finché non si risponde: una lista
    /// di domande sarebbe un'altra cosa da sbrigare.
    private var pendingLevelCheck: PantryItem? {
        viewModel.itemsNeedingLevelCheck.first { !dismissedLevelChecks.contains($0.id) }
    }

    private var visibleSections: [PantrySection] {
        guard showOnlyExpiring else { return viewModel.sections }

        let expiringIds = Set(viewModel.expiringSoonItems.map(\.id))
        return viewModel.sections.compactMap { section in
            let items = section.items.filter { expiringIds.contains($0.id) }
            guard !items.isEmpty else { return nil }
            return PantrySection(id: section.id, title: section.title, systemImage: section.systemImage, items: items)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Dispensa vuota", systemImage: "shippingbox")
        } description: {
            Text("Aggiungi quello che hai in casa, o importalo dallo scontrino dopo la spesa.")
        } actions: {
            VStack(spacing: 8) {
                Button("Aggiungi prodotto") {
                    isPresentingEditor = true
                }
                .buttonStyle(.borderedProminent)

                Button("Importa da uno scontrino") {
                    isPresentingImport = true
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
