import SwiftUI

/// Il posto da cui entra qualunque scontrino.
///
/// Fuori dalla spesa di proposito: la farmacia è una spesa quanto il
/// supermercato. Qui si fotografa, e NeatNest decide dove va cosa.
struct ReceiptScanHomeView: View {
    let userSession: UserSession

    var body: some View {
        Group {
            if let userId = userSession.currentUserId, !userId.isEmpty {
                ReceiptScanContentView(userId: userId, viewModel: ReceiptScanViewModel(userId: userId))
            } else {
                ContentUnavailableView(
                    "Accedi per registrare gli scontrini",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Gli scontrini sono legati al tuo account.")
                )
            }
        }
        .navigationTitle("Scontrini")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PurchaseDetectionSetupView()
                } label: {
                    Label("Rilevamento acquisti", systemImage: "sparkles")
                }
            }
        }
    }
}

struct ReceiptScanContentView: View {
    let userId: String

    @State var viewModel: ReceiptScanViewModel
    @State private var isPresentingScanner = false
    @State private var isPresentingPantryReview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isProcessing {
                    processingCard
                } else if let result = viewModel.lastResult {
                    ReceiptIntakeSummaryCard(result: result) {
                        isPresentingPantryReview = true
                    }
                } else {
                    introCard
                }

                if viewModel.canScan {
                    Button {
                        isPresentingScanner = true
                    } label: {
                        Label("Scansiona scontrino", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isProcessing)
                } else {
                    Text("La scansione richiede la fotocamera: provala su iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .fullScreenCover(isPresented: $isPresentingScanner) {
            ReceiptScannerView(
                onFinish: { images in
                    isPresentingScanner = false
                    _Concurrency.Task { await viewModel.process(images: images) }
                },
                onCancel: { isPresentingScanner = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingPantryReview) {
            PantryImportReviewView(viewModel: PantryImportViewModel(userId: userId))
        }
        .alert("Scontrini", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var processingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Sto leggendo lo scontrino…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text("Uno scontrino, due destinazioni")
                .font(.headline)

            Text("La spesa finisce sempre nei movimenti. Gli alimentari proseguono verso la dispensa, il resto no. Vale per il supermercato come per la farmacia.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// Cosa è stato fatto con lo scontrino appena letto.
struct ReceiptIntakeSummaryCard: View {
    let result: ReceiptIntakeResult
    let onOpenPantry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: result.triage.kind.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.triage.retailerName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(result.triage.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(result.triage.total, format: .euro)
                    .font(.title3.weight(.bold))
            }

            if result.hasInconsistentTotal {
                Label(
                    "La somma degli articoli non torna col totale stampato: controlla prima di fidarti.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if result.moneyEntry != nil {
                    outcomeRow(
                        icon: "checkmark.circle.fill",
                        tint: .green,
                        text: String(
                            localized: "receipt.intake.moneyRecorded",
                            defaultValue: "Spesa registrata nei movimenti"
                        )
                    )
                }

                if result.canFillPantry {
                    outcomeRow(
                        icon: "shippingbox.fill",
                        tint: .blue,
                        text: String(
                            localized: "receipt.intake.foodLines",
                            defaultValue: "\(result.triage.foodLines.count) prodotti alimentari pronti per la dispensa"
                        )
                    )
                }

                if !result.triage.otherLines.isEmpty {
                    outcomeRow(
                        icon: "bag",
                        tint: .secondary,
                        text: String(
                            localized: "receipt.intake.otherLines",
                            defaultValue: "\(result.triage.otherLines.count) righe non alimentari: solo spesa"
                        )
                    )
                }
            }

            if result.canFillPantry {
                Button(action: onOpenPantry) {
                    Label("Rivedi e porta in dispensa", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func outcomeRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }
}
