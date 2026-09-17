import SwiftUI

/// Elenco ricette ordinato per quanto è fattibile adesso.
struct RecipeHomeView: View {
    let userSession: UserSession

    var body: some View {
        RecipeContentView(viewModel: RecipeHomeViewModel(userId: userSession.currentUserId))
            .navigationTitle("Ricette")
            .navigationBarTitleDisplayMode(.large)
    }
}

struct RecipeContentView: View {
    @State var viewModel: RecipeHomeViewModel

    var body: some View {
        List {
            if !viewModel.rescueSuggestions.isEmpty && viewModel.searchText.isEmpty {
                Section {
                    ForEach(viewModel.rescueSuggestions) { availability in
                        NavigationLink {
                            RecipeDetailView(recipeId: availability.recipe.id, viewModel: viewModel)
                        } label: {
                            RecipeRow(availability: availability)
                        }
                    }
                } header: {
                    Label("Da usare prima che scada", systemImage: "clock.badge.exclamationmark")
                } footer: {
                    Text("Ricette che consumano quello che sta per andare a male.")
                }
            }

            Section {
                if viewModel.filteredAvailabilities.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ForEach(viewModel.filteredAvailabilities) { availability in
                        NavigationLink {
                            RecipeDetailView(recipeId: availability.recipe.id, viewModel: viewModel)
                        } label: {
                            RecipeRow(availability: availability)
                        }
                    }
                }
            } header: {
                Text(viewModel.filter.title)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                Picker("Filtro", selection: $viewModel.filter) {
                    ForEach(RecipeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                courseFilterBar
            }
            .padding(.vertical, 10)
            .background(.bar)
        }
        .searchable(text: $viewModel.searchText, prompt: Text("Cerca una ricetta o un ingrediente"))
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Ricette", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Riprova") { _Concurrency.Task { await viewModel.retry() } }
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Ricette", isPresented: Binding(
            get: { viewModel.infoMessage != nil },
            set: { if !$0 { viewModel.infoMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.infoMessage ?? "")
        }
        .task {
            await viewModel.start()
        }
    }

    private var courseFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(
                    title: String(localized: "recipes.course.all", defaultValue: "Tutti i piatti"),
                    icon: "square.grid.2x2",
                    isSelected: viewModel.courseFilter == nil
                ) {
                    viewModel.courseFilter = nil
                }

                ForEach(RecipeCourse.allCases) { course in
                    chip(
                        title: String(localized: course.title),
                        icon: course.icon,
                        isSelected: viewModel.courseFilter == course
                    ) {
                        viewModel.courseFilter = viewModel.courseFilter == course ? nil : course
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var emptyState: some View {
        if !viewModel.hasPantryData {
            ContentUnavailableView {
                Label("Dispensa vuota", systemImage: "shippingbox")
            } description: {
                Text("Riempi la dispensa e qui comparirà cosa puoi cucinare con quello che hai.")
            }
        } else {
            ContentUnavailableView {
                Label("Niente da mostrare", systemImage: "fork.knife")
            } description: {
                Text("Con questo filtro non c'è nessuna ricetta. Prova con “Tutte”.")
            }
        }
    }
}
