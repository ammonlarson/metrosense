import CoreLocation
import Combine
import UserNotifications

@MainActor
final class MetroViewModel: ObservableObject {
    @Published var tripState: MetroTripState = .idle
    @Published var nearestStation: MetroStation?
    @Published var speedKMH: Double = 0
    @Published var settings: NotificationSettings

    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    // Track departure station when a trip begins
    private var departureStation: MetroStation?
    private var hasNotifiedCurrentTrip = false
    private var metroSpeedStartTime: Date?

    init(locationService: LocationService = LocationService()) {
        self.locationService = locationService
        self.settings = NotificationSettings.load()
        bindLocation()
    }

    func start() {
        locationService.requestPermission()
        NotificationService.shared.requestPermission()
    }

    // MARK: - Private

    private func bindLocation() {
        locationService.$currentLocation
            .compactMap { $0 }
            .combineLatest(locationService.$currentSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location, speed in
                self?.evaluate(location: location, speed: speed)
            }
            .store(in: &cancellables)
    }

    private func evaluate(location: CLLocation, speed: Double) {
        speedKMH = speed * 3.6

        let nearby = nearbyStation(for: location)
        nearestStation = nearby

        // Send proximity notifications using the user's configured radius
        if settings.proximityEnabled {
            let allStations = MetroLine.all.flatMap { $0.stations }
            var stationsInRange = Set<String>()
            for station in allStations {
                let dist = station.distance(from: location)
                if dist <= settings.proximityRadius {
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

                // If requireStartAtStation is on, only trigger from a station
                if settings.requireStartAtStation && departureStation == nil && nearby == nil {
                    return
                }

                // Moving at metro speed — find the most likely line
                if let departure = departureStation ?? nearby,
                   let line = likelyLine(near: location, from: departure) {
                    departureStation = departure
                    tripState = .onMetro(line: line, fromStation: departure, speed: speed)
                    if !hasNotifiedCurrentTrip && settings.movementEnabled {
                        hasNotifiedCurrentTrip = true
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
        notifiedProximityStations.insert(station.name)

        let content = UNMutableNotificationContent()
        content.title = "Near Station"
        content.body = "You are near \(station.name)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "proximity-\(station.name)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func isMetroSpeed(_ speed: Double) -> Bool {
        speed >= settings.minimumSpeedMPS && speed <= settings.maximumSpeedMPS
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
