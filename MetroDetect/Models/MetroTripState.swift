import CoreLocation

enum MetroTripState: Equatable {
    /// Not enough data yet or user is stationary
    case idle
    /// User is near a station but not yet moving at metro speed
    case atStation(MetroStation)
    /// User is moving at metro speed on a detected line
    case onMetro(line: MetroLine.LineID, fromStation: MetroStation, speed: Double)
    /// Trip ended — arrived at destination station
    case arrived(line: MetroLine.LineID, from: MetroStation, to: MetroStation)

    static func == (lhs: MetroTripState, rhs: MetroTripState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.atStation(let a), .atStation(let b)): return a == b
        case (.onMetro(let la, let fa, _), .onMetro(let lb, let fb, _)):
            return la == lb && fa == fb
        case (.arrived(let la, let fa, let ta), .arrived(let lb, let fb, let tb)):
            return la == lb && fa == fb && ta == tb
        default: return false
        }
    }
}
