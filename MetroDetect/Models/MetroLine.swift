import CoreLocation

struct MetroLine: Identifiable {
    enum LineID: String, CaseIterable {
        case m1 = "M1"
        case m2 = "M2"
        case m3 = "M3"
        case m4 = "M4"
    }

    let id: LineID
    let stations: [MetroStation]

    var name: String { id.rawValue }
}

// MARK: - Copenhagen Metro Data

extension MetroLine {
    // Speed thresholds in m/s
    // Copenhagen Metro runs ~40–80 km/h between stations
    static let minimumSpeedMPS: Double = 8.0   // ~29 km/h — moving, not walking/cycling
    static let maximumSpeedMPS: Double = 25.0  // ~90 km/h — upper bound for metro

    static let all: [MetroLine] = [m1, m2, m3, m4]

    static let m1 = MetroLine(id: .m1, stations: [
        MetroStation(name: "Vanløse",            coordinate: .init(latitude: 55.6830, longitude: 12.4713), lines: [.m1]),
        MetroStation(name: "Flintholm",          coordinate: .init(latitude: 55.6814, longitude: 12.4864), lines: [.m1, .m2]),
        MetroStation(name: "Lindevang",          coordinate: .init(latitude: 55.6790, longitude: 12.4988), lines: [.m1]),
        MetroStation(name: "Fasanvej",           coordinate: .init(latitude: 55.6764, longitude: 12.5096), lines: [.m1]),
        MetroStation(name: "Frederiksberg Allé", coordinate: .init(latitude: 55.6736, longitude: 12.5222), lines: [.m1]),
        MetroStation(name: "Aksel Møllers Have", coordinate: .init(latitude: 55.6720, longitude: 12.5328), lines: [.m1]),
        MetroStation(name: "Forum",              coordinate: .init(latitude: 55.6727, longitude: 12.5416), lines: [.m1]),
        MetroStation(name: "Vanløse",            coordinate: .init(latitude: 55.6739, longitude: 12.5487), lines: [.m1]),
        MetroStation(name: "Frederiksberg",      coordinate: .init(latitude: 55.6797, longitude: 12.5327), lines: [.m1]),
        MetroStation(name: "Gammel Strand",      coordinate: .init(latitude: 55.6780, longitude: 12.5780), lines: [.m1]),
        MetroStation(name: "Kongens Nytorv",     coordinate: .init(latitude: 55.6795, longitude: 12.5850), lines: [.m1, .m2]),
        MetroStation(name: "Christianshavn",     coordinate: .init(latitude: 55.6736, longitude: 12.5930), lines: [.m1]),
        MetroStation(name: "Islands Brygge",     coordinate: .init(latitude: 55.6663, longitude: 12.5810), lines: [.m1]),
        MetroStation(name: "DR Byen",            coordinate: .init(latitude: 55.6600, longitude: 12.5784), lines: [.m1]),
        MetroStation(name: "Sundby",             coordinate: .init(latitude: 55.6549, longitude: 12.5858), lines: [.m1]),
        MetroStation(name: "Bella Center",       coordinate: .init(latitude: 55.6450, longitude: 12.5732), lines: [.m1]),
        MetroStation(name: "Ørestad",            coordinate: .init(latitude: 55.6310, longitude: 12.5697), lines: [.m1]),
        MetroStation(name: "Copenhagen Airport", coordinate: .init(latitude: 55.6147, longitude: 12.6561), lines: [.m2]),
    ])

    static let m2 = MetroLine(id: .m2, stations: [
        MetroStation(name: "Vanløse",            coordinate: .init(latitude: 55.6830, longitude: 12.4713), lines: [.m2]),
        MetroStation(name: "Flintholm",          coordinate: .init(latitude: 55.6814, longitude: 12.4864), lines: [.m1, .m2]),
        MetroStation(name: "Kongens Nytorv",     coordinate: .init(latitude: 55.6795, longitude: 12.5850), lines: [.m1, .m2]),
        MetroStation(name: "Copenhagen Airport", coordinate: .init(latitude: 55.6147, longitude: 12.6561), lines: [.m2]),
    ])

    static let m3 = MetroLine(id: .m3, stations: [
        MetroStation(name: "Orientkaj",          coordinate: .init(latitude: 55.7126, longitude: 12.6028), lines: [.m3]),
        MetroStation(name: "Nordhavn",           coordinate: .init(latitude: 55.7073, longitude: 12.5953), lines: [.m3]),
        MetroStation(name: "Poul Henningsens Plads", coordinate: .init(latitude: 55.7029, longitude: 12.5875), lines: [.m3]),
        MetroStation(name: "Østerport",          coordinate: .init(latitude: 55.7064, longitude: 12.5749), lines: [.m3]),
        MetroStation(name: "Marmorkirken",       coordinate: .init(latitude: 55.6888, longitude: 12.5876), lines: [.m3]),
        MetroStation(name: "Kongens Nytorv",     coordinate: .init(latitude: 55.6795, longitude: 12.5850), lines: [.m1, .m2, .m3]),
        MetroStation(name: "Gammel Strand",      coordinate: .init(latitude: 55.6780, longitude: 12.5780), lines: [.m3]),
        MetroStation(name: "Rådhuspladsen",      coordinate: .init(latitude: 55.6760, longitude: 12.5685), lines: [.m3]),
        MetroStation(name: "Enghave Plads",      coordinate: .init(latitude: 55.6691, longitude: 12.5481), lines: [.m3]),
        MetroStation(name: "Åmarken",            coordinate: .init(latitude: 55.6626, longitude: 12.5250), lines: [.m3]),
        MetroStation(name: "Mozarts Plads",      coordinate: .init(latitude: 55.6590, longitude: 12.5121), lines: [.m3]),
        MetroStation(name: "Sydhavn",            coordinate: .init(latitude: 55.6559, longitude: 12.4996), lines: [.m3]),
        MetroStation(name: "Teglholmen",         coordinate: .init(latitude: 55.6515, longitude: 12.5192), lines: [.m3]),
        MetroStation(name: "Sluseholmen",        coordinate: .init(latitude: 55.6459, longitude: 12.5325), lines: [.m3]),
        MetroStation(name: "København H",        coordinate: .init(latitude: 55.6726, longitude: 12.5655), lines: [.m3]),
        MetroStation(name: "Vanløse",            coordinate: .init(latitude: 55.6830, longitude: 12.4713), lines: [.m3]),
    ])

    static let m4 = MetroLine(id: .m4, stations: [
        MetroStation(name: "København H",        coordinate: .init(latitude: 55.6726, longitude: 12.5655), lines: [.m4]),
        MetroStation(name: "København H (M4)",   coordinate: .init(latitude: 55.6726, longitude: 12.5655), lines: [.m4]),
        MetroStation(name: "Axeltorv",           coordinate: .init(latitude: 55.6756, longitude: 12.5659), lines: [.m4]),
        MetroStation(name: "Rådhuspladsen",      coordinate: .init(latitude: 55.6760, longitude: 12.5685), lines: [.m4]),
    ])
}
