import CoreLocation

struct MetroStation: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let lines: [MetroLine.LineID]

    init(name: String, coordinate: CLLocationCoordinate2D, lines: [MetroLine.LineID]) {
        self.id = name
        self.name = name
        self.coordinate = coordinate
        self.lines = lines
    }

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

// MARK: - Station Catalog

extension MetroStation {
    // M1 only
    static let vanlose = MetroStation(name: "Vanløse", coordinate: .init(latitude: 55.6830, longitude: 12.4713), lines: [.m1, .m2, .m3])
    static let lindevang = MetroStation(name: "Lindevang", coordinate: .init(latitude: 55.6790, longitude: 12.4988), lines: [.m1])
    static let fasanvej = MetroStation(name: "Fasanvej", coordinate: .init(latitude: 55.6764, longitude: 12.5096), lines: [.m1])
    static let frederiksbergAlle = MetroStation(name: "Frederiksberg Allé", coordinate: .init(latitude: 55.6736, longitude: 12.5222), lines: [.m1])
    static let akselMollersHave = MetroStation(name: "Aksel Møllers Have", coordinate: .init(latitude: 55.6720, longitude: 12.5328), lines: [.m1])
    static let forum = MetroStation(name: "Forum", coordinate: .init(latitude: 55.6727, longitude: 12.5416), lines: [.m1])
    static let frederiksberg = MetroStation(name: "Frederiksberg", coordinate: .init(latitude: 55.6797, longitude: 12.5327), lines: [.m1])
    static let norreport = MetroStation(name: "Nørreport", coordinate: .init(latitude: 55.6739, longitude: 12.5487), lines: [.m1, .m2])
    static let christianshavn = MetroStation(name: "Christianshavn", coordinate: .init(latitude: 55.6736, longitude: 12.5930), lines: [.m1, .m2])
    static let islandsBrygge = MetroStation(name: "Islands Brygge", coordinate: .init(latitude: 55.6663, longitude: 12.5810), lines: [.m1])
    static let drByen = MetroStation(name: "DR Byen", coordinate: .init(latitude: 55.6600, longitude: 12.5784), lines: [.m1])
    static let sundby = MetroStation(name: "Sundby", coordinate: .init(latitude: 55.6549, longitude: 12.5858), lines: [.m1])
    static let bellaCenter = MetroStation(name: "Bella Center", coordinate: .init(latitude: 55.6450, longitude: 12.5732), lines: [.m1])
    static let orestad = MetroStation(name: "Ørestad", coordinate: .init(latitude: 55.6310, longitude: 12.5697), lines: [.m1])
    static let vestamager = MetroStation(name: "Vestamager", coordinate: .init(latitude: 55.6193, longitude: 12.5755), lines: [.m1])

    // M1 + M2 shared
    static let flintholm = MetroStation(name: "Flintholm", coordinate: .init(latitude: 55.6814, longitude: 12.4864), lines: [.m1, .m2])

    // M2 only
    static let copenhagenAirport = MetroStation(name: "Copenhagen Airport", coordinate: .init(latitude: 55.6147, longitude: 12.6561), lines: [.m2])
    static let lergravsparken = MetroStation(name: "Lergravsparken", coordinate: .init(latitude: 55.6706, longitude: 12.6018), lines: [.m2])
    static let amagerstrand = MetroStation(name: "Amager Strand", coordinate: .init(latitude: 55.6633, longitude: 12.6175), lines: [.m2])
    static let femoren = MetroStation(name: "Femøren", coordinate: .init(latitude: 55.6556, longitude: 12.6297), lines: [.m2])
    static let kastrup = MetroStation(name: "Kastrup", coordinate: .init(latitude: 55.6396, longitude: 12.6417), lines: [.m2])
    static let lufthavnen = MetroStation(name: "Lufthavnen", coordinate: .init(latitude: 55.6299, longitude: 12.6499), lines: [.m2])

    // M3 only
    static let orientkaj = MetroStation(name: "Orientkaj", coordinate: .init(latitude: 55.7126, longitude: 12.6028), lines: [.m3])
    static let nordhavn = MetroStation(name: "Nordhavn", coordinate: .init(latitude: 55.7073, longitude: 12.5953), lines: [.m3])
    static let poulHenningsenPlads = MetroStation(name: "Poul Henningsens Plads", coordinate: .init(latitude: 55.7029, longitude: 12.5875), lines: [.m3])
    static let osterport = MetroStation(name: "Østerport", coordinate: .init(latitude: 55.7064, longitude: 12.5749), lines: [.m3])
    static let marmorkirken = MetroStation(name: "Marmorkirken", coordinate: .init(latitude: 55.6888, longitude: 12.5876), lines: [.m3, .m4])
    static let enghavePlads = MetroStation(name: "Enghave Plads", coordinate: .init(latitude: 55.6691, longitude: 12.5481), lines: [.m3, .m4])
    static let amarken = MetroStation(name: "Åmarken", coordinate: .init(latitude: 55.6626, longitude: 12.5250), lines: [.m3])
    static let mozartsPlads = MetroStation(name: "Mozarts Plads", coordinate: .init(latitude: 55.6590, longitude: 12.5121), lines: [.m3])
    static let sydhavn = MetroStation(name: "Sydhavn", coordinate: .init(latitude: 55.6559, longitude: 12.4996), lines: [.m3])
    static let teglholmen = MetroStation(name: "Teglholmen", coordinate: .init(latitude: 55.6515, longitude: 12.5192), lines: [.m3])
    static let sluseholmen = MetroStation(name: "Sluseholmen", coordinate: .init(latitude: 55.6459, longitude: 12.5325), lines: [.m3])

    // Multi-line shared stations
    static let kongensNytorv = MetroStation(name: "Kongens Nytorv", coordinate: .init(latitude: 55.6795, longitude: 12.5850), lines: [.m1, .m2, .m3, .m4])
    static let gammelStrand = MetroStation(name: "Gammel Strand", coordinate: .init(latitude: 55.6780, longitude: 12.5780), lines: [.m1, .m3, .m4])
    static let radhuspladsen = MetroStation(name: "Rådhuspladsen", coordinate: .init(latitude: 55.6760, longitude: 12.5685), lines: [.m3, .m4])
    static let kobenhavnH = MetroStation(name: "København H", coordinate: .init(latitude: 55.6726, longitude: 12.5655), lines: [.m3, .m4])

    // M4 only
    static let havneholmen = MetroStation(name: "Havneholmen", coordinate: .init(latitude: 55.6660, longitude: 12.5570), lines: [.m4])
    static let fisketorvet = MetroStation(name: "Fisketorvet", coordinate: .init(latitude: 55.6630, longitude: 12.5530), lines: [.m4])
    static let vigerslev = MetroStation(name: "Vigerslev Allé", coordinate: .init(latitude: 55.6571, longitude: 12.5170), lines: [.m4])
    static let nyEllebjerg = MetroStation(name: "Ny Ellebjerg", coordinate: .init(latitude: 55.6500, longitude: 12.5110), lines: [.m4])
}
