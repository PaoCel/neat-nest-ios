import SwiftUI

struct GS1InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    currentStateSection
                    gs1BenefitsSection
                    comparisonSection
                    ctaSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.06), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("GS1 Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Come migliorerebbe con GS1?")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("GS1 Italy gestisce i codici GTIN a livello globale. Con accesso ai dati GS1, Smart Grocery diventerebbe enormemente piu potente.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var currentStateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "exclamationmark.triangle.fill", title: "Stato attuale", color: .orange)

            VStack(spacing: 10) {
                LimitationRow(
                    emoji: "🔴",
                    title: "Matching prodotti incerto",
                    detail: "Il fuzzy matching testuale non garantisce corrispondenze perfette tra fonti diverse."
                )
                LimitationRow(
                    emoji: "🟡",
                    title: "Copertura parziale",
                    detail: "Solo prodotti in offerta o presenti nei volantini digitali."
                )
                LimitationRow(
                    emoji: "🔴",
                    title: "No dati nutrizionali",
                    detail: "Senza anagrafica strutturata, allergeni e valori nutrizionali non sono disponibili."
                )
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var gs1BenefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "checkmark.seal.fill", title: "Con integrazione GS1", color: .green)

            VStack(spacing: 10) {
                BenefitRow(
                    emoji: "🟢",
                    title: "Matching perfetto al 100%",
                    detail: "Il codice GTIN identifica univocamente ogni prodotto. Zero ambiguita."
                )
                BenefitRow(
                    emoji: "🟢",
                    title: "Copertura completa anagrafica",
                    detail: "Tutti i prodotti registrati, non solo quelli in offerta."
                )
                BenefitRow(
                    emoji: "🟢",
                    title: "Dati nutrizionali e allergeni",
                    detail: "Informazioni strutturate per ogni prodotto: calorie, ingredienti, allergeni."
                )
                BenefitRow(
                    emoji: "🟢",
                    title: "Varianti e formati",
                    detail: "Tutte le varianti di un prodotto (formati, gusti) collegate automaticamente."
                )
                BenefitRow(
                    emoji: "🟢",
                    title: "Integrazione real-time",
                    detail: "Possibilita di collegamento diretto con i sistemi dei retailer."
                )
                BenefitRow(
                    emoji: "🌍",
                    title: "Scalabilita internazionale",
                    detail: "GTIN e uno standard globale: la stessa logica funziona in qualsiasi paese."
                )
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "arrow.left.arrow.right", title: "Confronto", color: .blue)

            HStack(spacing: 16) {
                ComparisonCard(
                    title: "Oggi",
                    items: [
                        "Fuzzy matching ~70%",
                        "Solo promo/volantini",
                        "Nessun dato nutrizionale",
                        "Solo Italia"
                    ],
                    color: .orange
                )

                ComparisonCard(
                    title: "Con GS1",
                    items: [
                        "Match GTIN 100%",
                        "Anagrafica completa",
                        "Nutrizione + allergeni",
                        "Standard globale"
                    ],
                    color: .green
                )
            }
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Text("Powered by fonti pubbliche")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Qualita ottimizzabile con integrazione GS1 GTIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Views

private struct SectionTitle: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
        }
    }
}

private struct LimitationRow: View {
    let emoji: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BenefitRow: View {
    let emoji: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ComparisonCard: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)

            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    GS1InfoView()
}
