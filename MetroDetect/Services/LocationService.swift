import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0  // m/s
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // Minimum distance (meters) before a new location event fires
        manager.distanceFilter = 10
        // Allow background location updates
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .otherNavigation
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Reject invalid fixes (negative accuracy means invalid)
        guard location.horizontalAccuracy >= 0 else { return }

        let isStale = location.timestamp.timeIntervalSinceNow < -30
        let isTooInaccurate = location.horizontalAccuracy > 200

        // Accept any valid, non-stale fix within 200m accuracy.
        // Also accept any fix if the current location is stale to avoid
        // showing an outdated position indefinitely.
        let currentIsStale = currentLocation.map {
            $0.timestamp.timeIntervalSinceNow < -30
        } ?? true

        guard !isStale, (!isTooInaccurate || currentIsStale) else { return }

        currentLocation = location
        // CLLocation.speed is -1 when unavailable; clamp to 0
        currentSpeed = max(0, location.speed)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
    }
}
