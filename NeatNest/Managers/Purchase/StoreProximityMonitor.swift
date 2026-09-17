import Foundation
import CoreLocation

/// Si accorge di quando esci da un supermercato.
///
/// È la fonte che vede quello che Wallet non può vedere: i contanti, il
/// bancomat, la carta di qualcun altro. In cambio non sa quanto hai speso.
///
/// Sorveglia solo l'**uscita**: mentre sei dentro non c'è niente da chiedere.
@MainActor
final class StoreProximityMonitor: NSObject {
    /// iOS non sorveglia più di 20 regioni per app. Si tengono i negozi più
    /// vicini, che sono quelli dove l'utente va davvero.
    static let maxMonitoredRegions = 20
    /// Raggio del recinto attorno al punto vendita.
    static let regionRadius: CLLocationDistance = 150

    private let manager: CLLocationManager
    private var monitoredRetailers: [String: Retailer] = [:]

    /// Chiamata quando l'utente esce da un punto vendita sorvegliato.
    var onStoreExit: ((Retailer) -> Void)?
    /// Chiamata quando arriva finalmente il permesso "sempre": è il momento in
    /// cui i recinti si possono piazzare davvero.
    var onAuthorizationGranted: (() -> Void)?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// Il geofence in background richiede l'autorizzazione "sempre", che è la
    /// più pesante da chiedere. Si domanda solo quando l'utente ha già detto
    /// di volere questa funzione.
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var isAvailable: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    }

    /// Sorveglia i punti vendita più vicini alla posizione corrente.
    func startMonitoring(retailers: [Retailer]) {
        guard isAvailable, manager.authorizationStatus == .authorizedAlways else { return }

        stopMonitoring()

        let candidates = nearestRetailers(from: retailers)

        for retailer in candidates {
            guard let latitude = retailer.latitude, let longitude = retailer.longitude else { continue }

            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                radius: Self.regionRadius,
                identifier: retailer.id
            )
            region.notifyOnEntry = false
            region.notifyOnExit = true

            monitoredRetailers[retailer.id] = retailer
            manager.startMonitoring(for: region)
        }
    }

    func stopMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        monitoredRetailers.removeAll()
    }

    private func nearestRetailers(from retailers: [Retailer]) -> [Retailer] {
        let geolocated = retailers.filter { $0.latitude != nil && $0.longitude != nil && $0.isActive }

        guard let here = manager.location else {
            return Array(geolocated.prefix(Self.maxMonitoredRegions))
        }

        return geolocated
            .sorted { lhs, rhs in
                distance(from: here, to: lhs) < distance(from: here, to: rhs)
            }
            .prefix(Self.maxMonitoredRegions)
            .map { $0 }
    }

    private func distance(from location: CLLocation, to retailer: Retailer) -> CLLocationDistance {
        guard let latitude = retailer.latitude, let longitude = retailer.longitude else {
            return .greatestFiniteMagnitude
        }

        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }
}

extension StoreProximityMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        _Concurrency.Task { @MainActor [weak self] in
            guard let self, let retailer = self.monitoredRetailers[region.identifier] else { return }
            self.onStoreExit?(retailer)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        _Concurrency.Task { @MainActor [weak self] in
            guard let self, status == .authorizedAlways else { return }
            self.onAuthorizationGranted?()
        }
    }
}
