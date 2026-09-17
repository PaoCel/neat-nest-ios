import SwiftUI

struct GroceryListsView: View {
    private let userSession: UserSession
    @State private var viewModel: GroceryListsViewModel

    @State private var isPresentingCreateSheet = false
    @State private var isPresentingQuickAdd = false
    @State private var quickAddConfirmation: Int?
    @State private var editingList: UserGroceryList?
    @State private var pendingDeletion: UserGroceryList?

    init(userSession: UserSession, viewModel: GroceryListsViewModel? = nil) {
        self.userSession = userSession
        _viewModel = State(initialValue: viewModel ?? GroceryListsViewModel(userSession: userSession))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SmartGrocerySurface(tint: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Liste sincronizzate")
                            .font(.headline)

                        Text("La lista principale viene creata automaticamente. Puoi aggiungere liste dedicate senza perdere il flusso principale.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.isLoading && viewModel.listSummaries.isEmpty {
                    SmartGrocerySurface(tint: .green) {
                        ProgressView("Sto caricando le liste...")
                            .tint(.green)
                    }
                } else {
                    ForEach(viewModel.listSummaries) { summary in
                        groceryListCard(summary: summary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Shopping Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.large)
                }
                .accessibilityLabel(Text("Nuova lista"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let userId = userSession.currentUserId, !userId.isEmpty {
                Button {
                    isPresentingQuickAdd = true
                } label: {
                    Label("Segna qualcosa al volo", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .sheet(isPresented: $isPresentingQuickAdd) {
            if let userId = userSession.currentUserId {
                QuickAddView(userId: userId) { count in
                    quickAddConfirmation = count
                }
            }
        }
        .alert(
            "Aggiunti alla lista",
            isPresented: Binding(
                get: { quickAddConfirmation != nil },
                set: { if !$0 { quickAddConfirmation = nil } }
            ),
            presenting: quickAddConfirmation
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { count in
            Text("\(count) articoli aggiunti alla lista principale.")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            GroceryListEditorSheet(
                title: "Nuova lista",
                initialTitle: ""
            ) { title in
                await viewModel.createList(title: title)
            }
        }
        .sheet(item: $editingList) { list in
            GroceryListEditorSheet(
                title: "Rinomina lista",
                initialTitle: list.title
            ) { title in
                await viewModel.renameList(list, title: title)
            }
        }
        .confirmationDialog("Elimina lista", isPresented: deleteDialogBinding) {
            if let pendingDeletion {
                Button("Elimina \(pendingDeletion.title)", role: .destructive) {
                    _Concurrency.Task {
                        _ = await viewModel.deleteList(pendingDeletion)
                        self.pendingDeletion = nil
                    }
                }
            }

            Button("Annulla", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Questa azione elimina la lista e i suoi articoli collegati.")
        }
        .alert("Shopping Lists", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func groceryListCard(summary: GroceryListSummary) -> some View {
        SmartGrocerySurface(tint: summary.list.isDefault ? .green : .mint) {
            HStack(alignment: .top, spacing: 16) {
                NavigationLink(destination: GroceryListDetailView(list: summary.list, userSession: userSession)) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(summary.list.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)

                            if summary.list.isDefault {
                                SmartGroceryStatusBadge(title: "Principale", tint: .green)
                            }
                        }

                        Text("Aggiornata \(SmartGroceryFormatters.relativeDate(summary.list.updatedAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            SmartGroceryStatusBadge(title: "\(summary.itemCount) articoli", tint: Color.primary)
                            SmartGroceryStatusBadge(title: "\(summary.activeCount) da comprare", tint: .green)
                            if summary.purchasedCount > 0 {
                                SmartGroceryStatusBadge(title: "\(summary.purchasedCount) presi", tint: .blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Rinomina") {
                        editingList = summary.list
                    }

                    if !summary.list.isDefault {
                        Button("Elimina", role: .destructive) {
                            pendingDeletion = summary.list
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
        }
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

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    pendingDeletion = nil
                }
            }
        )
    }
}

@MainActor
private struct GroceryListsViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()

    var body: some View {
        NavigationStack {
            GroceryListsView(
                userSession: session,
                viewModel: PreviewSupport.makeGroceryListsViewModel()
            )
        }
    }
}

#Preview("Shopping Lists") {
    GroceryListsViewPreviewContainer()
}

private struct GroceryListEditorSheet: View {
    let title: String
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var listTitle: String
    @State private var isSaving = false

    init(title: String, initialTitle: String, onSave: @escaping (String) async -> Bool) {
        self.title = title
        self.onSave = onSave
        _listTitle = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SmartGrocerySurface(tint: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nome lista")
                            .font(.headline)

                        TextField("Spesa settimanale, cena ospiti...", text: $listTitle)
                            .textInputAutocapitalization(.sentences)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                    }
                }

                Spacer()
            }
            .padding(20)
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
                                let didSave = await onSave(listTitle)
                                isSaving = false
                                if didSave {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(listTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
