import SwiftUI

/// Entrate, uscite, differenza. Niente altro.
struct MoneyHomeView: View {
    let userSession: UserSession

    var body: some View {
        Group {
            if let userId = userSession.currentUserId, !userId.isEmpty {
                MoneyContentView(viewModel: MoneyHomeViewModel(userId: userId))
            } else {
                ContentUnavailableView(
                    "Accedi per vedere i movimenti",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("I movimenti sono legati al tuo account.")
                )
            }
        }
        .navigationTitle("Soldi")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MoneyContentView: View {
    @State var viewModel: MoneyHomeViewModel
    @State private var isPresentingEditor = false
    @State private var editorKind: MoneyEntry.Kind = .expense
    @State private var entryPendingDeletion: MoneyEntry?

    var body: some View {
        List {
            Section {
                MoneyBalanceCard(balance: viewModel.balance, period: viewModel.period)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if viewModel.isEmpty {
                Section {
                    emptyState
                }
            }

            ForEach(viewModel.entriesByDay, id: \.day) { group in
                Section {
                    ForEach(group.entries) { entry in
                        MoneyEntryRow(entry: entry)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    entryPendingDeletion = entry
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                Picker("Periodo", selection: $viewModel.period) {
                    ForEach(MoneyPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                kindFilterBar
            }
            .padding(.vertical, 10)
            .background(.bar)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    editorKind = .expense
                    isPresentingEditor = true
                } label: {
                    Label("Uscita", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    editorKind = .income
                    isPresentingEditor = true
                } label: {
                    Label("Entrata", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .overlay {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView()
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            MoneyEntryEditorView(kind: editorKind) { amount, note, date in
                _Concurrency.Task {
                    await viewModel.add(kind: editorKind, amount: amount, note: note, date: date)
                }
            }
        }
        .alert(
            "Eliminare il movimento?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            presenting: entryPendingDeletion
        ) { entry in
            Button("Elimina", role: .destructive) {
                _Concurrency.Task { await viewModel.delete(entry) }
            }
            Button("Annulla", role: .cancel) { }
        }
        .alert("Soldi", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Riprova") { viewModel.retry() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.start()
        }
    }

    private var kindFilterBar: some View {
        HStack(spacing: 8) {
            chip(title: String(localized: "money.filter.all", defaultValue: "Tutti"), isSelected: viewModel.kindFilter == nil) {
                viewModel.kindFilter = nil
            }

            ForEach(MoneyEntry.Kind.allCases) { kind in
                chip(title: String(localized: kind.title), isSelected: viewModel.kindFilter == kind) {
                    viewModel.kindFilter = viewModel.kindFilter == kind ? nil : kind
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessun movimento", systemImage: "eurosign.circle")
        } description: {
            Text("Segna un'entrata o un'uscita. Gli scontrini che scansioni finiscono qui da soli.")
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

/// Il saldo del periodo, con entrate e uscite sotto.
struct MoneyBalanceCard: View {
    let balance: MoneyBalance
    let period: MoneyPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Differenza")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(balance.delta, format: .euro)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(balance.isPositive ? Color.green : Color.red)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 20) {
                amountColumn(
                    title: String(localized: "money.card.income", defaultValue: "Entrate"),
                    amount: balance.income,
                    tint: .green
                )

                Divider().frame(height: 32)

                amountColumn(
                    title: String(localized: "money.card.expenses", defaultValue: "Uscite"),
                    amount: balance.expenses,
                    tint: .red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func amountColumn(title: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(amount, format: .euro)
                .font(.headline)
                .foregroundStyle(tint)
        }
    }
}

struct MoneyEntryRow: View {
    let entry: MoneyEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind.icon)
                .font(.title3)
                .foregroundStyle(entry.kind == .income ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note.isEmpty ? String(localized: entry.kind.title) : entry.note)
                    .font(.body)
                    .lineLimit(1)

                if entry.source == .receipt {
                    Label(entry.source.title, systemImage: "doc.text.viewfinder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(entry.signedAmount, format: .euro)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .income ? Color.green : Color.primary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
