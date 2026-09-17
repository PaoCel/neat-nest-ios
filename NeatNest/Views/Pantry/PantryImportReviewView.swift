import SwiftUI

/// Revisione di uno scontrino prima che finisca in dispensa.
///
/// Niente entra in dispensa senza che l'utente l'abbia visto: le righe che lo
/// scontrino non ha saputo riconoscere sono in cima, con il testo grezzo sotto
/// il nome, così si può correggere "ARTICOLO 1" in "Pane".
struct PantryImportReviewView: View {
    @State var viewModel: PantryImportViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingScanner = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading || viewModel.isProcessingScan {
                    scanProgress
                } else if !viewModel.hasReceipts {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Dallo scontrino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.canScan {
                        Button {
                            isPresentingScanner = true
                        } label: {
                            Label("Scansiona scontrino", systemImage: "camera.viewfinder")
                        }
                        .accessibilityHint(Text("Apre la fotocamera per leggere uno scontrino"))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.hasReceipts {
                        Menu {
                            Button("Seleziona tutto") { viewModel.includeAll() }
                            Button("Deseleziona tutto") { viewModel.excludeAll() }
                        } label: {
                            Label("Altre azioni", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.hasReceipts {
                    confirmBar
                }
            }
            .alert("Dispensa", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $isPresentingScanner) {
                ReceiptScannerView(
                    onFinish: { images in
                        isPresentingScanner = false
                        _Concurrency.Task { await viewModel.importScanned(images: images) }
                    },
                    onCancel: { isPresentingScanner = false }
                )
                .ignoresSafeArea()
            }
            .alert("Scontrino letto", isPresented: Binding(
                get: { viewModel.scanWarning != nil },
                set: { if !$0 { viewModel.dismissScanWarning() } }
            )) {
                Button("Va bene", role: .cancel) { }
            } message: {
                Text(viewModel.scanWarning ?? "")
            }
            .task {
                await viewModel.load()
            }
            .onChange(of: viewModel.didApply) { _, didApply in
                if didApply { dismiss() }
            }
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("Scontrino", selection: receiptSelection) {
                    ForEach(viewModel.receipts) { receipt in
                        VStack(alignment: .leading) {
                            Text(receipt.retailerName)
                            Text(receipt.purchaseDate, format: .dateTime.day().month(.abbreviated).year())
                        }
                        .tag(receipt.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            if let plan = viewModel.plan {
                if plan.isEmpty {
                    Section {
                        Text("Da questo scontrino non c'è niente da mettere in dispensa.")
                            .foregroundStyle(.secondary)
                    }
                }

                candidateSection(
                    title: String(localized: "pantry.import.section.review", defaultValue: "Da chiarire"),
                    footer: String(
                        localized: "pantry.import.section.review.footer",
                        defaultValue: "Lo scontrino non li ha riconosciuti. Correggi il nome o togli la spunta."
                    ),
                    candidates: plan.candidates.filter(\.needsReview)
                )

                candidateSection(
                    title: String(localized: "pantry.import.section.new", defaultValue: "Nuovi in dispensa"),
                    footer: nil,
                    candidates: plan.candidates.filter { !$0.needsReview && !$0.kind.isMerge }
                )

                candidateSection(
                    title: String(localized: "pantry.import.section.merge", defaultValue: "Si sommano a quello che hai"),
                    footer: nil,
                    candidates: plan.candidates.filter(\.kind.isMerge)
                )

                if !plan.skippedLineTexts.isEmpty {
                    Section {
                        DisclosureGroup {
                            ForEach(plan.skippedLineTexts, id: \.self) { text in
                                Text(text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            Text("\(plan.skippedLineTexts.count) righe ignorate")
                                .font(.subheadline)
                        }
                    } footer: {
                        Text("Detersivi, sacchetti e righe illeggibili non entrano in dispensa.")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func candidateSection(
        title: String,
        footer: String?,
        candidates: [PantryIngestionCandidate]
    ) -> some View {
        if !candidates.isEmpty {
            Section {
                ForEach(candidates) { candidate in
                    PantryImportRow(candidate: candidate, viewModel: viewModel)
                }
            } header: {
                Text(title)
            } footer: {
                if let footer {
                    Text(footer)
                }
            }
        }
    }

    private var receiptSelection: Binding<String> {
        Binding(
            get: { viewModel.selectedReceipt?.id ?? "" },
            set: { newValue in
                if let receipt = viewModel.receipts.first(where: { $0.id == newValue }) {
                    viewModel.select(receipt)
                }
            }
        )
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            if viewModel.reviewCount > 0 {
                Label(
                    "\(viewModel.reviewCount) prodotti ancora da chiarire",
                    systemImage: "questionmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Button {
                _Concurrency.Task { await viewModel.apply() }
            } label: {
                if viewModel.isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Aggiungi \(viewModel.includedCount) prodotti")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.includedCount == 0 || viewModel.isApplying)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var scanProgress: some View {
        VStack(spacing: 14) {
            ProgressView()

            if viewModel.isProcessingScan {
                Text("Sto leggendo lo scontrino…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessuno scontrino", systemImage: "doc.text.viewfinder")
        } description: {
            Text("Fotografa lo scontrino appena torni dalla spesa: NeatNest legge gli articoli e li porta in dispensa.")
        } actions: {
            if viewModel.canScan {
                Button("Scansiona scontrino") {
                    isPresentingScanner = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("La scansione richiede la fotocamera: provala su iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Riga modificabile di una proposta di import.
struct PantryImportRow: View {
    let candidate: PantryIngestionCandidate
    let viewModel: PantryImportViewModel

    @State private var editedName: String = ""
    @State private var quantityValue: Double = 1
    @State private var unit: PantryUnit = .piece

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.setIncluded(!candidate.isIncluded, for: candidate.id)
                } label: {
                    Image(systemName: candidate.isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(candidate.isIncluded ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.isIncluded
                    ? Text("Escludi dalla dispensa")
                    : Text("Includi in dispensa"))

                VStack(alignment: .leading, spacing: 2) {
                    if candidate.needsReview {
                        TextField("Nome prodotto", text: $editedName)
                            .textInputAutocapitalization(.sentences)
                            .onSubmit { viewModel.setName(editedName, for: candidate.id) }
                    } else {
                        Text(candidate.item.displayName)
                            .font(.body.weight(.medium))
                    }

                    Text(candidate.rawLineText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if candidate.kind.isMerge {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Si somma a un prodotto già in dispensa"))
                }
            }

            if candidate.isIncluded {
                HStack(spacing: 10) {
                    TextField(
                        "Quantità",
                        value: $quantityValue,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: quantityValue) { _, newValue in
                        viewModel.setQuantity(newValue, unit: unit, for: candidate.id)
                    }

                    Picker("Unità", selection: $unit) {
                        ForEach(PantryUnit.allCases) { unit in
                            Text(unit.pickerLabel).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: unit) { _, newValue in
                        viewModel.setQuantity(quantityValue, unit: newValue, for: candidate.id)
                    }

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(PantryStorage.allCases) { storage in
                            Button {
                                viewModel.setStorage(storage, for: candidate.id)
                            } label: {
                                Label {
                                    Text(storage.title)
                                } icon: {
                                    Image(systemName: storage.icon)
                                }
                            }
                        }
                    } label: {
                        Label {
                            Text(candidate.item.storage.title)
                        } icon: {
                            Image(systemName: candidate.item.storage.icon)
                        }
                        .font(.caption)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .opacity(candidate.isIncluded ? 1 : 0.5)
        .onAppear {
            editedName = candidate.item.displayName
            quantityValue = candidate.item.quantity.value
            unit = candidate.item.quantity.unit
        }
    }
}
