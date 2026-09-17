import SwiftUI

struct LetsShopPreferenceView: View {
    let list: UserGroceryList

    @AppStorage("smartGrocery.loyaltyPricing") private var loyaltyPricingEnabled = true
    @State private var viewModel: LetsShopPreferenceViewModel
    @State private var recommendationSet: ShoppingRecommendationSet?
    @State private var isShowingResults = false

    init(list: UserGroceryList, userSession: UserSession, viewModel: LetsShopPreferenceViewModel? = nil) {
        self.list = list
        _viewModel = State(initialValue: viewModel ?? LetsShopPreferenceViewModel(list: list, userSession: userSession))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroSection
                sliderSection
                metricsSection
                basketPreviewSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Facciamo la spesa")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                _Concurrency.Task {
                    recommendationSet = await viewModel.generateRecommendations(
                        considerLoyaltyPricing: loyaltyPricingEnabled
                    )
                    isShowingResults = recommendationSet != nil
                }
            } label: {
                Group {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Label("Calcola il piano spesa", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: viewModel.selectedMode.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.thinMaterial)
            .disabled(viewModel.isGenerating || viewModel.activeItemsCount == 0)
            .opacity(viewModel.activeItemsCount == 0 ? 0.55 : 1)
        }
        .navigationDestination(isPresented: $isShowingResults) {
            if let recommendationSet {
                LetsShopResultsView(
                    recommendationSet: recommendationSet,
                    list: list
                )
            }
        }
        .alert("Let's Shop", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var heroSection: some View {
        SmartGroceryHeroCard(colors: viewModel.selectedMode.gradientColors) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Let's Shop")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    SmartGroceryStatusBadge(
                        title: viewModel.selectedMode.localizedTitle,
                        tint: .white
                    )
                }

                Text(list.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.selectedMode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    SmartGroceryStatusBadge(
                        title: viewModel.selectedMode.localizedTitle,
                        tint: .white
                    )
                    SmartGroceryStatusBadge(
                        title: "\(viewModel.activeItemsCount) articoli attivi",
                        tint: .white
                    )
                    SmartGroceryStatusBadge(
                        title: loyaltyPricingEnabled ? "Loyalty attiva" : "Solo prezzi standard",
                        tint: .white
                    )
                }
            }
        }
    }

    private var sliderSection: some View {
        SmartGrocerySurface(tint: viewModel.selectedMode.tintColor) {
            VStack(alignment: .leading, spacing: 18) {
                SmartGrocerySectionHeader(
                    title: "Preferenza",
                    subtitle: "Da comodita a risparmio."
                ) {
                    SmartGroceryStatusBadge(
                        title: "\(Int(viewModel.preferenceValue.rounded()))",
                        tint: viewModel.selectedMode.tintColor
                    )
                }

                Slider(value: $viewModel.preferenceValue, in: 0...100, step: 1)
                    .tint(viewModel.selectedMode.tintColor)

                HStack {
                    Text("Convenienza")
                    Spacer()
                    Text("Bilanciato")
                    Spacer()
                    Text("Risparmio")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Text(viewModel.selectedMode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    ForEach(ShoppingRecommendationKind.allCases) { kind in
                        PreferenceModePill(
                            kind: kind,
                            isSelected: kind == viewModel.selectedMode
                        )
                    }
                }
            }
        }
    }

    private var metricsSection: some View {
        SmartGrocerySurface(tint: .mint) {
            SmartGrocerySectionHeader(
                title: "Copertura",
                subtitle: "Quello che l'engine vede adesso."
            ) {
                EmptyView()
            }

            if viewModel.isLoading, viewModel.preparation == nil {
                ProgressView("Sto preparando i prezzi retailer...")
                    .tint(.green)
            } else if let preparation = viewModel.preparation {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    spacing: 12
                ) {
                    metricCard(
                        title: "Match catalogo",
                        value: "\(preparation.resolvedCount)/\(preparation.activeCount)",
                        subtitle: "voci gia normalizzate"
                    )

                    metricCard(
                        title: "Prezzi disponibili",
                        value: "\(preparation.pricedCount)",
                        subtitle: "articoli gia coperti"
                    )

                    metricCard(
                        title: "Retailer attivi",
                        value: "\(preparation.retailers.count)",
                        subtitle: "fonti pronte per l'engine"
                    )

                    metricCard(
                        title: "Ultimo refresh",
                        value: preparation.latestPriceUpdate.map(SmartGroceryFormatters.relativeDate) ?? "N/D",
                        subtitle: "freschezza dati demo"
                    )
                }
            } else {
                Text("Non riesco ancora a caricare il perimetro prezzi di questa lista.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var basketPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmartGrocerySectionHeader(
                title: "Carrello",
                subtitle: "Gli attivi entrano nel calcolo."
            ) {
                EmptyView()
            }

            if let preparation = viewModel.preparation, !preparation.activeItems.isEmpty {
                SmartGrocerySurface(tint: .green) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(preparation.previewItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.isResolved ? "checkmark.seal.fill" : "questionmark.circle.fill")
                                    .foregroundStyle(item.isResolved ? .green : .orange)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName)
                                        .font(.subheadline.weight(.semibold))

                                    Text(SmartGroceryFormatters.quantityLabel(quantity: item.quantity, unit: item.unit))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                SmartGroceryStatusBadge(
                                    title: item.isResolved ? "Catalogo" : "Custom",
                                    tint: item.isResolved ? .green : .orange
                                )
                            }
                        }

                        if preparation.activeItems.count > preparation.previewItems.count {
                            Text("+\(preparation.activeItems.count - preparation.previewItems.count) altri articoli")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if viewModel.isLoading {
                SmartGrocerySurface(tint: .green) {
                    ProgressView("Sto leggendo la lista attiva...")
                        .tint(.green)
                }
            } else {
                SmartGroceryEmptyStateCard(
                    icon: "cart.badge.questionmark",
                    title: "Nessun articolo attivo",
                    message: "Aggiungi almeno un prodotto alla lista per generare una raccomandazione."
                )
            }
        }
    }

    private func metricCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
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

@MainActor
private struct LetsShopPreferenceViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()

    var body: some View {
        NavigationStack {
            LetsShopPreferenceView(
                list: PreviewSupport.defaultList,
                userSession: session,
                viewModel: PreviewSupport.makeLetsShopPreferenceViewModel()
            )
        }
    }
}

#Preview("Let's Shop Preference") {
    LetsShopPreferenceViewPreviewContainer()
}

private struct PreferenceModePill: View {
    let kind: ShoppingRecommendationKind
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? kind.tintColor : .primary)

            Text(kind.sliderRangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? kind.tintColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? kind.tintColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
