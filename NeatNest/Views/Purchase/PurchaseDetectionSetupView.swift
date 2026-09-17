import SwiftUI
import CoreLocation

/// Spiega e accende il rilevamento acquisti.
///
/// Due strade indipendenti: una la accende l'app, l'altra la deve creare
/// l'utente nelle Scorciatoie. Entrambe utili da sole, migliori insieme —
/// e va detto chiaramente cosa vede ciascuna, perché si chiede l'accesso alla
/// posizione e quello è un permesso che va guadagnato, non estorto.
struct PurchaseDetectionSetupView: View {
    @State private var manager = PurchaseDetectionManager.shared
    @State private var isRequestingLocation = false

    var body: some View {
        List {
            Section {
                Text("NeatNest può accorgersi da solo che hai comprato qualcosa e chiederti se registrarlo. Due strade, ognuna cieca dove l'altra vede.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: geofencingBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Quando esci da un negozio", systemImage: "location.circle")
                        Text("Funziona con qualunque pagamento, contanti compresi. Non sa quanto hai speso.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isRequestingLocation)

                if manager.isGeofencingActive {
                    Label("Attivo", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isLocationDenied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("L'accesso alla posizione è negato. Serve “Sempre” per accorgersi dell'uscita anche ad app chiusa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Apri Impostazioni") {
                            openSettings()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            } header: {
                Text("Posizione")
            } footer: {
                Text("La posizione resta sul tuo iPhone: NeatNest la usa per capire quando esci da un supermercato, e non la manda da nessuna parte.")
            }

            Section {
                walletStep(number: 1, text: "Apri l'app Comandi rapidi e vai su Automazione")
                walletStep(number: 2, text: "Nuova automazione, scegli Wallet (su iOS 17 si chiama Transazione)")
                walletStep(number: 3, text: "Seleziona le carte che usi per la spesa")
                walletStep(number: 4, text: "Come azione scegli “Registra pagamento” di NeatNest")
                walletStep(number: 5, text: "Attiva Esegui immediatamente, così non chiede conferma ogni volta")
            } header: {
                Text("Pagamenti Apple Pay")
            } footer: {
                Text("Questa la crei tu una volta sola. Sa l'importo esatto, ma vede solo Apple Pay: contanti e carta fisica passano dalla posizione.")
            }

            if !manager.pendingPrompts.isEmpty {
                Section("In attesa di risposta") {
                    ForEach(manager.pendingPrompts) { prompt in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prompt.notificationBody)
                                .font(.subheadline)

                            Text(prompt.detectedAt, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Rilevamento acquisti")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await manager.start()
        }
    }

    private var isLocationDenied: Bool {
        !manager.locationAuthorizationIsFull && !manager.isGeofencingActive
    }

    private var geofencingBinding: Binding<Bool> {
        Binding(
            get: { manager.isGeofencingActive },
            set: { isOn in
                if isOn {
                    isRequestingLocation = true
                    _Concurrency.Task {
                        await manager.enableGeofencing()
                        isRequestingLocation = false
                    }
                } else {
                    manager.disableGeofencing()
                }
            }
        )
    }

    private func walletStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
