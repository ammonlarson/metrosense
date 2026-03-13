import CoreLocation

struct MetroStation: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let lines: [MetroLine.LineID]

    // Radius (meters) within which we consider the user to be "at" this station
    static let proximityRadius: CLLocationDistance = 150

    static func == (lhs: MetroStation, rhs: MetroStation) -> Bool {
        lhs.id == rhs.id
    }
}

extension MetroStation {
    func distance(from location: CLLocation) -> CLLocationDistance {
        let stationLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return location.distance(from: stationLocation)
    }

    func isNearby(_ location: CLLocation) -> Bool {
        distance(from: location) <= MetroStation.proximityRadius
    }
}
