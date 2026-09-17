import Foundation
import Observation

/// Tiene insieme le due fonti e decide quando parlare.
///
/// Wallet e posizione non si conoscono fra loro: questo è il punto in cui i
/// loro segnali si incontrano, si fondono se raccontano lo stesso acquisto, e
/// producono **una sola** domanda all'utente.
@MainActor
@Observable
final class PurchaseDetectionManager {
    private(set) var pendingPrompts: [PurchasePrompt] = []
    private(set) var isGeofencingActive = false

    @ObservationIgnored private let store: PurchaseSignalStore
    @ObservationIgnored private let correlator: PurchaseSignalCorrelator
    @ObservationIgnored private let notifier: PurchaseNotifier
    @ObservationIgnored private let monitor: StoreProximityMonitor
    @ObservationIgnored private let groceryRepository: SmartGroceryRepository
    /// Richieste già notificate: la stessa non si ripropone a ogni avvio.
    @ObservationIgnored private var notifiedPromptIds: Set<String> = []

    static let shared = PurchaseDetectionManager()

    // `PurchaseNotifier` e `StoreProximityMonitor` vivono sul main actor e non
    // possono stare in un valore di default: quello viene valutato nel contesto
    // del chiamante, che main actor non è.
    init(
        store: PurchaseSignalStore = PurchaseSignalStore(),
        correlator: PurchaseSignalCorrelator = PurchaseSignalCorrelator(),
        notifier: PurchaseNotifier? = nil,
        monitor: StoreProximityMonitor? = nil,
        groceryRepository: SmartGroceryRepository = SmartGroceryRepository()
    ) {
        self.store = store
        self.correlator = correlator
        self.notifier = notifier ?? PurchaseNotifier()
        self.monitor = monitor ?? StoreProximityMonitor()
        self.groceryRepository = groceryRepository

        configureMonitor()
    }

    // MARK: - Avvio

    func start() async {
        notifier.registerCategory()
        await refreshPrompts(notifyNew: false)
    }

    /// Accende la sorveglianza dei negozi. Da chiamare solo dopo che l'utente
    /// ha chiesto esplicitamente questa funzione.
    func enableGeofencing() async {
        monitor.requestAuthorization()
        _ = await notifier.requestAuthorizationIfNeeded()
        await startMonitoringStores()
    }

    func disableGeofencing() {
        monitor.stopMonitoring()
        isGeofencingActive = false
    }

    var locationAuthorizationIsFull: Bool {
        monitor.authorizationStatus == .authorizedAlways
    }

    // MARK: - Ingresso dei segnali

    /// Un pagamento Apple Pay, arrivato dall'automazione Wallet.
    func recordWalletTransaction(amount: Double, merchantName: String?) async {
        let signal = PurchaseSignal(
            source: .wallet,
            merchantName: merchantName?.trimmed.isEmpty == false ? merchantName?.trimmed : nil,
            amount: amount > 0 ? amount : nil
        )

        _ = await store.record(signal)
        await refreshPrompts(notifyNew: true)
    }

    /// L'utente è appena uscito da un punto vendita conosciuto.
    func recordStoreExit(_ retailer: Retailer) async {
        let signal = PurchaseSignal(
            source: .geofence,
            merchantName: retailer.name,
            retailerId: retailer.id
        )

        _ = await store.record(signal)
        await refreshPrompts(notifyNew: true)
    }

    // MARK: - Risposte dell'utente

    /// L'utente ha risposto, in un senso o nell'altro: la domanda si chiude.
    func resolve(promptId: String) async {
        await store.resolve(promptId: promptId)
        notifier.cancel(promptId: promptId)
        notifiedPromptIds.remove(promptId)
        await refreshPrompts(notifyNew: false)
    }

    func prompt(withId id: String) -> PurchasePrompt? {
        pendingPrompts.first { $0.id == id }
    }

    // MARK: - Interno

    private func configureMonitor() {
        monitor.onStoreExit = { [weak self] retailer in
            _Concurrency.Task { await self?.recordStoreExit(retailer) }
        }

        monitor.onAuthorizationGranted = { [weak self] in
            _Concurrency.Task { await self?.startMonitoringStores() }
        }
    }

    private func startMonitoringStores() async {
        guard monitor.isAvailable, locationAuthorizationIsFull else {
            isGeofencingActive = false
            return
        }

        let retailers = (try? await groceryRepository.fetchRetailers()) ?? []
        let geolocated = retailers.filter { $0.latitude != nil && $0.longitude != nil }

        guard !geolocated.isEmpty else {
            isGeofencingActive = false
            return
        }

        monitor.startMonitoring(retailers: geolocated)
        isGeofencingActive = true
    }

    /// Ricalcola le domande aperte e notifica solo quelle mai viste.
    private func refreshPrompts(notifyNew: Bool) async {
        let signals = await store.all()
        let prompts = correlator.prompts(from: signals)
        pendingPrompts = prompts

        guard notifyNew else { return }

        for prompt in prompts where !notifiedPromptIds.contains(prompt.id) {
            notifiedPromptIds.insert(prompt.id)
            await notifier.notify(prompt)
        }
    }
}
