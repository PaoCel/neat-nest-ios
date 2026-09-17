import SwiftUI

struct SmartGroceryVoiceAssistantView: View {
    @EnvironmentObject private var voiceManager: SmartGroceryVoiceManager
    @State private var selectedPhraseIndex = 0

    private let supportedPhrases: [VoicePhraseExample] = [
        VoicePhraseExample(
            activation: "Aggiungi alla Smart Grocery di NeatNest",
            siriReply: "Quale prodotto vuoi aggiungere?",
            userReply: "Latte Arborea"
        ),
        VoicePhraseExample(
            activation: "Aggiungi alla Smart Grocery di NeatNest",
            siriReply: "Quale prodotto vuoi aggiungere?",
            userReply: "Latte senza lattosio"
        ),
        VoicePhraseExample(
            activation: "Aggiungi alla Smart Grocery di NeatNest",
            siriReply: "Quale prodotto vuoi aggiungere?",
            userReply: "Mezzo litro di latte senza lattosio"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroSection
                supportedPhrasesSection
                howItWorksSection

                if let lastProcessedResult = voiceManager.lastProcessedResult {
                    lastResultSection(lastProcessedResult)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Aggiungi con Siri")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        SmartGrocerySurface(tint: .indigo) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Guida Siri")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)

                    Spacer()

                    SmartGroceryStatusBadge(title: "App Shortcut", tint: .indigo)
                }

                Text("Scegli la frase e seguila passo per passo")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Questa schermata serve solo da guida rapida: scegli un esempio e prova esattamente quella frase con Siri.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                selectedPhraseHighlight
            }
        }
    }

    private var supportedPhrasesSection: some View {
        SmartGrocerySurface(tint: .indigo) {
            SmartGrocerySectionHeader(
                title: "Frasi supportate",
                subtitle: "Tocca un esempio per scegliere la frase esatta da dire."
            ) {
                EmptyView()
            }

            VStack(spacing: 12) {
                ForEach(Array(supportedPhrases.enumerated()), id: \.offset) { index, phrase in
                    guidedPhraseCard(
                        phrase: phrase,
                        isSelected: selectedPhraseIndex == index
                    )
                    .onTapGesture {
                        selectedPhraseIndex = index
                    }
                }
            }
        }
    }

    private var howItWorksSection: some View {
        SmartGrocerySurface(tint: .green) {
            SmartGrocerySectionHeader(
                title: "Come funziona",
                subtitle: "L'intent resta sottile e riusa il pipeline Smart Grocery gia esistente."
            ) {
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 14) {
                stepRow(
                    icon: "waveform.badge.mic",
                    title: "Siri raccoglie il prodotto in un secondo passaggio",
                    message: "L'App Shortcut attiva Smart Grocery e Siri ti chiede quale prodotto vuoi aggiungere."
                )

                stepRow(
                    icon: "tray.full.fill",
                    title: "NeatNest usa la lista principale",
                    message: "La richiesta viene elaborata sull'account autenticato e aggiunta alla Smart Grocery di default."
                )

                stepRow(
                    icon: "sparkles",
                    title: "Il matcher decide se risolvere o tenere custom",
                    message: "Se il prodotto non viene riconosciuto, resta comunque visibile come item custom non risolto."
                )
            }
        }
    }

    private func lastResultSection(_ result: SmartGroceryVoiceProcessedResult) -> some View {
        SmartGrocerySurface(tint: .mint) {
            SmartGrocerySectionHeader(
                title: "Ultimo inserimento vocale",
                subtitle: "Feedback immediato dell'ultimo comando elaborato."
            ) {
                Button("Nascondi") {
                    voiceManager.clearLastProcessedResult()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(result.itemName)
                    .font(.headline)

                Text("Aggiunto a \(result.listTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if result.itemName != result.rawInputText {
                    Text(result.rawInputText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let suggestion = result.suggestion {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                        Text(
                            suggestion.lastPurchasedAt.map {
                                "Ultimo acquisto \(SmartGroceryFormatters.relativeDate($0)). Lo hai terminato?"
                            } ?? "Lo avevi gia comprato. Vuoi riattivarlo nella lista?"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.green.opacity(0.08))
                    )
                }
            }
        }
    }

    private var selectedPhraseHighlight: some View {
        let phrase = supportedPhrases[selectedPhraseIndex]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Frase da dire")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("“\(phrase.activation)”")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Poi rispondi: “\(phrase.userReply)”")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.indigo.opacity(0.08))
        )
    }

    private func guidedPhraseCard(
        phrase: VoicePhraseExample,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "mic.fill")
                    .foregroundStyle(isSelected ? .green : .indigo)
                Text(isSelected ? "Frase selezionata" : "Prova con Siri")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("“\(phrase.activation)”")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Siri: “\(phrase.siriReply)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Tu: “\(phrase.userReply)”")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Color.indigo.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.indigo.opacity(0.32) : Color.clear, lineWidth: 1)
        )
    }

    private func stepRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct VoicePhraseExample {
    let activation: String
    let siriReply: String
    let userReply: String
}

@MainActor
private struct SmartGroceryVoiceAssistantPreviewContainer: View {
    private let voiceManager = PreviewSupport.makeVoiceManager()

    var body: some View {
        NavigationStack {
            SmartGroceryVoiceAssistantView()
                .environmentObject(voiceManager)
        }
    }
}

#Preview("Voice Assistant") {
    SmartGroceryVoiceAssistantPreviewContainer()
}
