import SwiftUI

struct SmartGroceryHomeView: View {
    private enum HomeTab: String, CaseIterable, Identifiable {
        case lists = "Liste"
        case suggestions = "Suggerimenti"
        case spending = "Spesa & storico"

        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .lists:
                return "Le liste aperte e ancora da completare."
            case .suggestions:
                return "Prodotti che potresti dover ricomprare a breve."
            case .spending:
                return "Storico e analisi restano in una vista dedicata."
            }
        }
    }

    private let userSession: UserSession
    @State private var viewModel: SmartGroceryHomeViewModel
    @State private var selectedTab: HomeTab = .lists

    init(userSession: UserSession, viewModel: SmartGroceryHomeViewModel? = nil) {
        self.userSession = userSession
        _viewModel = State(initialValue: viewModel ?? SmartGroceryHomeViewModel(userSession: userSession))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                tabSelectorSection
                activeTabSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Smart Grocery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SmartGrocerySettingsView()) {
                    Image(systemName: "slider.horizontal.3")
                        .imageScale(.large)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .alert("Smart Grocery", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var heroSection: some View {
        Group {
            if let summary = viewModel.defaultListSummary {
                NavigationLink(destination: GroceryListDetailView(list: summary.list, userSession: userSession)) {
                    SmartGrocerySurface(tint: .green) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(summary.list.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if summary.list.isDefault {
                                    SmartGroceryStatusBadge(title: "Principale", tint: .green)
                                }
                            }

                            Text(primarySummaryText(for: summary))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                SmartGroceryStatusBadge(title: "\(summary.activeCount) da comprare", tint: .green)
                                SmartGroceryStatusBadge(title: "\(summary.itemCount) totali", tint: .primary)
                                if visibleListSummaries.count > 1 {
                                    SmartGroceryStatusBadge(title: "\(visibleListSummaries.count) liste aperte", tint: .mint)
                                }
                            }

                            HStack {
                                Text("Apri lista")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                SmartGrocerySurface(tint: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sto preparando la tua area spesa")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Creo la lista principale e sincronizzo il catalogo prodotti.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ProgressView()
                            .tint(.green)
                    }
                }
            }
        }
    }

    private var tabSelectorSection: some View {
        Picker("Vista", selection: $selectedTab) {
            ForEach(HomeTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var activeTabSection: some View {
        switch selectedTab {
        case .lists:
            listsSection
        case .suggestions:
            suggestionsSection
        case .spending:
            spendingSection
        }
    }

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Liste attive",
                subtitle: nil
            ) {
                NavigationLink(destination: GroceryListsView(userSession: userSession)) {
                    Text("Tutte")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if viewModel.isLoading && viewModel.listSummaries.isEmpty {
                SmartGrocerySurface(tint: .green) {
                    ProgressView("Sto caricando le liste...")
                        .tint(.green)
                }
            } else if visibleListSummaries.isEmpty {
                SmartGroceryEmptyStateCard(
                    icon: "checkmark.circle",
                    title: "Nessuna lista aperta",
                    message: "Le liste con articoli ancora da comprare compariranno qui. Puoi comunque aprire l'archivio completo."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(visibleListSummaries) { summary in
                            NavigationLink(destination: GroceryListDetailView(list: summary.list, userSession: userSession)) {
                                SmartGroceryListPreviewCard(summary: summary)
                                    .frame(width: 280)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Suggerimenti",
                subtitle: selectedTab.subtitle
            ) {
                EmptyView()
            }

            if viewModel.upcomingSuggestions.isEmpty {
                SmartGroceryEmptyStateCard(
                    icon: "lightbulb",
                    title: "Ancora nessun suggerimento",
                    message: "Quando avremo abbastanza storico, qui vedrai prodotti da ricomprare."
                )
            } else {
                SmartGrocerySurface(tint: .green) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(viewModel.upcomingSuggestions, id: \.id) { item in
                            SmartGrocerySuggestionChip(item: item)
                        }
                    }
                }
            }
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Spesa & storico",
                subtitle: selectedTab.subtitle
            ) {
                NavigationLink(destination: SmartGrocerySpendingView(userSession: userSession)) {
                    Text("Apri")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            NavigationLink(destination: SmartGrocerySpendingView(userSession: userSession)) {
                SmartGrocerySurface(tint: .orange) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Storico spesa", systemImage: "receipt")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)

                            Spacer()

                            SmartGroceryStatusBadge(title: "Sezione dedicata", tint: .orange)
                        }

                        Text("Apri import, categorie e acquisti")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Qui trovi il riepilogo rapido. L'analisi completa della spesa resta in una schermata separata, piu leggibile e meno affollata.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Vai a Spesa & storico")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var visibleListSummaries: [GroceryListSummary] {
        viewModel.listSummaries.filter { summary in
            summary.activeCount > 0 || summary.itemCount == 0
        }
    }

    private func primarySummaryText(for summary: GroceryListSummary) -> String {
        if summary.itemCount == 0 {
            return "La lista e pronta. Puoi iniziare ad aggiungere i primi prodotti."
        }

        if summary.purchasedCount == 0 {
            return "\(summary.activeCount) articoli ancora da comprare."
        }

        return "\(summary.activeCount) articoli ancora da comprare, \(summary.purchasedCount) gia acquistati."
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

@MainActor
private struct SmartGroceryHomeViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()

    var body: some View {
        NavigationStack {
            SmartGroceryHomeView(
                userSession: session,
                viewModel: PreviewSupport.makeSmartGroceryHomeViewModel()
            )
        }
    }
}

#Preview("Smart Grocery Home") {
    SmartGroceryHomeViewPreviewContainer()
}
