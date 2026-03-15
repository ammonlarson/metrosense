import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0  // m/s
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUsingDegradedLocation: Bool = false
    @Published var error: String?

    private static let accuracyThreshold: Double = 200
    private static let fallbackAccuracyThreshold: Double = 500
    private static let stalenessLimit: TimeInterval = -30

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

        let isStale = location.timestamp.timeIntervalSinceNow < Self.stalenessLimit
        let isTooInaccurate = location.horizontalAccuracy > Self.accuracyThreshold

        // Accept any valid, non-stale fix within the accuracy threshold.
        // When the current location is stale, accept fixes up to the fallback
        // threshold to avoid showing an outdated position indefinitely.
        let currentIsStale = currentLocation.map {
            $0.timestamp.timeIntervalSinceNow < Self.stalenessLimit
        } ?? true

        let withinFallback = location.horizontalAccuracy <= Self.fallbackAccuracyThreshold
        let usingFallback = isTooInaccurate && currentIsStale && withinFallback
        guard !isStale, (!isTooInaccurate || usingFallback) else { return }

        isUsingDegradedLocation = usingFallback
        error = nil
        currentLocation = location
        // CLLocation.speed is -1 when unavailable; clamp to 0
        currentSpeed = max(0, location.speed)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
    }
}
