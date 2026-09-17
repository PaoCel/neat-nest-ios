import SwiftUI

struct SmartGrocerySettingsView: View {
    @AppStorage("smartGrocery.preferenceStyle") private var preferenceStyle = GroceryPreferenceStyle.balanced.rawValue
    @AppStorage("smartGrocery.priceAlerts") private var priceAlertsEnabled = false
    @AppStorage("smartGrocery.loyaltyPricing") private var loyaltyPricingEnabled = true
    @AppStorage("smartGrocery.receiptImport") private var receiptImportEnabled = false

    var body: some View {
        Form {
            Section("Esperienza di acquisto") {
                Picker("Stile preferito", selection: $preferenceStyle) {
                    ForEach(GroceryPreferenceStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }

                Text("Questa preferenza verra usata piu avanti per personalizzare suggerimenti, ordinamento articoli e flusso Let's Shop.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Prezzi e loyalty") {
                Toggle("Avvisi prezzo", isOn: $priceAlertsEnabled)
                Toggle("Considera prezzi loyalty", isOn: $loyaltyPricingEnabled)
            }

            Section("Import e automazioni") {
                Toggle("Receipt import", isOn: $receiptImportEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text("In arrivo")
                        .font(.subheadline.weight(.semibold))

                    Text("OCR scontrini, confronto retailer e ottimizzazione della spesa verranno costruiti nel prossimo step sopra questa base.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Preferenze")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Smart Grocery Settings") {
    NavigationStack {
        SmartGrocerySettingsView()
    }
}
