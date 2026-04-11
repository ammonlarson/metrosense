import CoreLocation
import Combine

@MainActor
final class MetroViewModel: ObservableObject {
    @Published var tripState: MetroTripState = .idle
    @Published var nearestStation: MetroStation?
    @Published var nearestStationDistance: CLLocationDistance?
    @Published var speedKMH: Double = 0
    @Published var isUsingDegradedLocation: Bool = false
    @Published var isSignalLost: Bool = true
    @Published var settings: NotificationSettings

    var currentLocation: CLLocation? { locationService.currentLocation }
    var currentSpeed: Double { locationService.currentSpeed }
    var heading: CLHeading? { locationService.heading }

    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    // Track departure station when a trip begins
    private var departureStation: MetroStation?
    private var hasNotifiedCurrentTrip = false
    private var metroSpeedStartTime: Date?
    private(set) var lastMovementNotificationTime: Date?
    private(set) var lastProximityNotificationTime: Date?

    /// Maximum distance (meters) for showing the nearest station on the home screen.
    private static let nearestStationMaxDistance: CLLocationDistance = 10_000

    init(locationService: LocationService = LocationService()) {
        self.locationService = locationService
        self.settings = NotificationSettings.load()
        bindLocation()
        bindSettings()
    }

    func start() {
        locationService.requestPermission()
        NotificationService.shared.requestPermission()
    }

    // MARK: - Private

    private func bindSettings() {
        $settings
            .removeDuplicates {
                $0.rejsekortEnabled == $1.rejsekortEnabled
                    && $0.proximityRejsekortAction == $1.proximityRejsekortAction
                    && $0.movementRejsekortAction == $1.movementRejsekortAction
            }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { newSettings in
                NotificationService.shared.configure(settings: newSettings)
            }
            .store(in: &cancellables)
    }

    private func bindLocation() {
        locationService.$currentLocation
            .compactMap { $0 }
            .combineLatest(locationService.$currentSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location, speed in
                self?.evaluate(location: location, speed: speed)
            }
            .store(in: &cancellables)

        locationService.$isUsingDegradedLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$isUsingDegradedLocation)

        locationService.$isSignalLost
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSignalLost)
    }

    private func evaluate(location: CLLocation, speed: Double) {
        speedKMH = speed * 3.6

        let accuracy = location.horizontalAccuracy
        // Show the closest station within 10 km on the home screen.
        let closest = closestStation(for: location)
        nearestStation = closest?.station
        nearestStationDistance = closest?.distance

        // Use accuracy-aware check for proximity notifications (avoid false alerts)
        // but use the standard check for trip state transitions (avoid missing
        // arrivals when GPS is degraded underground).
        let nearby = nearbyStation(for: location)

        // Send proximity notifications using the user's configured radius.
        // When accuracy exceeds the configured radius, skip proximity alerts
        // because we cannot reliably confirm the user is within range.
        if settings.proximityEnabled, accuracy <= settings.proximityRadius {
            let allStations = MetroLine.all.flatMap { $0.stations }
            var stationsInRange = Set<String>()
            for station in allStations {
                let dist = station.distance(from: location)
                if (dist + accuracy) <= settings.proximityRadius {
                    stationsInRange.insert(station.name)
                    let shouldNotify: Bool
                    switch settings.proximityStationFilter {
                    case .all:
                        shouldNotify = true
                    case .selected(let names):
                        shouldNotify = names.contains(station.name)
                    }
                    if shouldNotify {
                        sendProximityNotificationIfNeeded(station: station)
                    }
                }
            }
            // Clear dedup for stations the user has left
            notifiedProximityStations.subtract(notifiedProximityStations.subtracting(stationsInRange))
        }

        switch tripState {
        case .idle, .atStation:
            if isMetroSpeed(speed) {
                // Track when metro speed started for sustained duration
                if metroSpeedStartTime == nil {
                    metroSpeedStartTime = Date()
                }

                let sustained = Date().timeIntervalSince(metroSpeedStartTime ?? Date())
                guard sustained >= settings.sustainedDurationSeconds else { return }

                // If requireStartAtStation is on, only trigger from an applicable station
                // and only when moving toward a neighboring station
                if let filter = settings.requireStartAtStationFilter {
                    let candidate = departureStation ?? nearby
                    switch filter {
                    case .all:
                        if candidate == nil { return }
                    case .selected(let names):
                        guard let station = candidate, names.contains(station.name) else { return }
                    }

                    // Direction check: movement must head toward a neighboring station
                    if let origin = candidate, !origin.isMovingTowardNeighbor(currentLocation: location) {
                        return
                    }
                }

                // Moving at metro speed — find the most likely line
                if let departure = departureStation ?? nearby,
                   let line = likelyLine(near: location, from: departure) {
                    departureStation = departure
                    tripState = .onMetro(line: line, fromStation: departure, speed: speed)
                    if !hasNotifiedCurrentTrip && settings.movementEnabled && isMovementCooldownElapsed() {
                        hasNotifiedCurrentTrip = true
                        lastMovementNotificationTime = Date()
                        NotificationService.shared.sendMetroDetected(
                            line: line.rawValue,
                            fromStation: departure.name
                        )
                    }
                }
            } else {
                metroSpeedStartTime = nil
                if let station = nearby {
                    departureStation = station
                    tripState = .atStation(station)
                } else {
                    tripState = .idle
                    hasNotifiedCurrentTrip = false
                }
            }

        case .onMetro(let line, let from, _):
            if isMetroSpeed(speed) {
                // Still on metro — update speed
                tripState = .onMetro(line: line, fromStation: from, speed: speed)
                // Check if we've arrived at a new station
                if let arrived = nearby, arrived != from {
                    tripState = .arrived(line: line, from: from, to: arrived)
                    departureStation = arrived
                }
            } else if let station = nearby {
                // Slowed down at a station — arrival
                tripState = .arrived(line: line, from: from, to: station)
                departureStation = station
            } else {
                // Slowed down away from any station — treat as arrived/idle
                tripState = .idle
                metroSpeedStartTime = nil
                hasNotifiedCurrentTrip = false
            }

        case .arrived(_, _, let to):
            // Reset to atStation at the arrival point after a moment
            tripState = .atStation(to)
            departureStation = to
            metroSpeedStartTime = nil
            hasNotifiedCurrentTrip = false
        }
    }

    private var notifiedProximityStations = Set<String>()

    private func sendProximityNotificationIfNeeded(station: MetroStation) {
        guard !notifiedProximityStations.contains(station.name) else { return }
        guard isProximityCooldownElapsed() else { return }
        notifiedProximityStations.insert(station.name)
        lastProximityNotificationTime = Date()

        NotificationService.shared.sendProximityNotification(
            stationName: station.name
        )
    }

    private func isMovementCooldownElapsed() -> Bool {
        guard settings.movementCooldownSeconds > 0 else { return true }
        guard let lastTime = lastMovementNotificationTime else { return true }
        return Date().timeIntervalSince(lastTime) >= settings.movementCooldownSeconds
    }

    private func isProximityCooldownElapsed() -> Bool {
        guard settings.movementCooldownSeconds > 0 else { return true }
        guard let lastTime = lastProximityNotificationTime else { return true }
        return Date().timeIntervalSince(lastTime) >= settings.movementCooldownSeconds
    }

    private func isMetroSpeed(_ speed: Double) -> Bool {
        speed >= settings.minimumSpeedMPS && speed <= settings.maximumSpeedMPS
    }

    private func closestStation(for location: CLLocation) -> (station: MetroStation, distance: CLLocationDistance)? {
        let allStations = MetroLine.all.flatMap { $0.stations }
        var best: (station: MetroStation, distance: CLLocationDistance)?
        for station in allStations {
            let dist = station.distance(from: location)
            if dist <= Self.nearestStationMaxDistance, dist < (best?.distance ?? .infinity) {
                best = (station, dist)
            }
        }
        return best
    }

    private func nearbyStation(for location: CLLocation) -> MetroStation? {
        let allStations = MetroLine.all.flatMap { $0.stations }
        return allStations
            .filter { $0.isNearby(location) }
            .min { $0.distance(from: location) < $1.distance(from: location) }
    }

    private func likelyLine(near location: CLLocation, from departure: MetroStation) -> MetroLine.LineID? {
        // Find lines that serve the departure station
        let candidateLines = departure.lines

        // Among those, pick the line whose next station is closest to current position
        return candidateLines.min { lineA, lineB in
            let distA = distanceToNearestStation(on: lineA, from: location, excluding: departure)
            let distB = distanceToNearestStation(on: lineB, from: location, excluding: departure)
            return distA < distB
        }
    }

    private func distanceToNearestStation(
        on lineID: MetroLine.LineID,
        from location: CLLocation,
        excluding station: MetroStation
    ) -> CLLocationDistance {
        guard let line = MetroLine.all.first(where: { $0.id == lineID }) else {
            return .infinity
        }
        return line.stations
            .filter { $0 != station }
            .map { $0.distance(from: location) }
            .min() ?? .infinity
    }
}
