import CoreLocation

struct MetroStation: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let coordinate: CLLocationCoordinate2D
    let lines: [MetroLine.LineID]

    // Radius (meters) within which we consider the user to be "at" this station
    static let proximityRadius: CLLocationDistance = 150

    static func == (lhs: MetroStation, rhs: MetroStation) -> Bool {
        lhs.name == rhs.name
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
    // City Hubs (M1/M2/M3/M4)
    static let kongensNytorv = MetroStation(name: "Kongens Nytorv", coordinate: .init(latitude: 55.6792989727498, longitude: 12.585175945578222), lines: [.m1, .m2, .m3, .m4])
    static let frederiksberg = MetroStation(name: "Frederiksberg", coordinate: .init(latitude: 55.68123061670384, longitude: 12.531705986951017), lines: [.m1, .m2, .m3, .m4])

    // M1 + M2 shared
    static let vanlose = MetroStation(name: "Vanløse", coordinate: .init(latitude: 55.68721048711406, longitude: 12.491376053217971), lines: [.m1, .m2])
    static let flintholm = MetroStation(name: "Flintholm", coordinate: .init(latitude: 55.68576708833653, longitude: 12.49922305517447), lines: [.m1, .m2])
    static let lindevang = MetroStation(name: "Lindevang", coordinate: .init(latitude: 55.68346545210913, longitude: 12.51314824643724), lines: [.m1, .m2])
    static let fasanvej = MetroStation(name: "Fasanvej Solbjerg", coordinate: .init(latitude: 55.6816679938997, longitude: 12.523118956679255), lines: [.m1, .m2])
    static let forum = MetroStation(name: "Forum", coordinate: .init(latitude: 55.6817815431066, longitude: 12.55262325130255), lines: [.m1, .m2])
    static let norreport = MetroStation(name: "Nørreport", coordinate: .init(latitude: 55.683500879017934, longitude: 12.572217869297827), lines: [.m1, .m2])
    static let christianshavn = MetroStation(name: "Christianshavn", coordinate: .init(latitude: 55.672124875230914, longitude: 12.591389346762924), lines: [.m1, .m2])

    // M1 only
    static let islandsBrygge = MetroStation(name: "Islands Brygge", coordinate: .init(latitude: 55.66354884909702, longitude: 12.585268012291744), lines: [.m1])
    static let drByen = MetroStation(name: "DR Byen", coordinate: .init(latitude: 55.655815923974075, longitude: 12.58901199752968), lines: [.m1])
    static let sundby = MetroStation(name: "Sundby", coordinate: .init(latitude: 55.64524412916406, longitude: 12.585771112705475), lines: [.m1])
    static let bellaCenter = MetroStation(name: "Bella Center", coordinate: .init(latitude: 55.638069040351446, longitude: 12.582942473839982), lines: [.m1])
    static let orestad = MetroStation(name: "Ørestad", coordinate: .init(latitude: 55.62903482442495, longitude: 12.579388310925347), lines: [.m1])
    static let vestamager = MetroStation(name: "Vestamager", coordinate: .init(latitude: 55.619372014410885, longitude: 12.57558483278802), lines: [.m1])

    // M2 only
    static let amagerbro = MetroStation(name: "Amagerbro", coordinate: .init(latitude: 55.663551488856115, longitude: 12.602707547478053), lines: [.m2])
    static let lergravsparken = MetroStation(name: "Lergravsparken", coordinate: .init(latitude: 55.6622086360987, longitude: 12.616716213510049), lines: [.m2])
    static let oresund = MetroStation(name: "Øresund", coordinate: .init(latitude: 55.661342507118334, longitude: 12.628828616193923), lines: [.m2])
    static let amagerstrand = MetroStation(name: "Amager Strand", coordinate: .init(latitude: 55.656122511761765, longitude: 12.631882018424838), lines: [.m2])
    static let femoren = MetroStation(name: "Femøren", coordinate: .init(latitude: 55.645215096036424, longitude: 12.638350916887616), lines: [.m2])
    static let kastrup = MetroStation(name: "Kastrup", coordinate: .init(latitude: 55.63563659393103, longitude: 12.647010876329706), lines: [.m2])
    static let kobenhavnAirport = MetroStation(name: "Københavns Lufthavn", coordinate: .init(latitude: 55.630687770514264, longitude: 12.649273805333694), lines: [.m2])

    // M3 + M4 shared
    static let osterport = MetroStation(name: "Østerport", coordinate: .init(latitude: 55.692545345142435, longitude: 12.587313935476747), lines: [.m3, .m4])
    static let marmorkirken = MetroStation(name: "Marmorkirken", coordinate: .init(latitude: 55.68521081596391, longitude: 12.588803144665478), lines: [.m3, .m4])
    static let gammelStrand = MetroStation(name: "Gammel Strand", coordinate: .init(latitude: 55.67772047634749, longitude: 12.579338116711565), lines: [.m3, .m4])
    static let radhuspladsen = MetroStation(name: "Rådhuspladsen", coordinate: .init(latitude: 55.676414042957525, longitude: 12.568703205521818), lines: [.m3, .m4])
    static let kobenhavnH = MetroStation(name: "København H", coordinate: .init(latitude: 55.671747873103286, longitude: 12.56423171017014), lines: [.m3, .m4])

    // M3 only
    static let enghavePlads = MetroStation(name: "Enghave Plads", coordinate: .init(latitude: 55.667225879957186, longitude: 12.546782026920464), lines: [.m3, .m4])
    static let frederiksbergAlle = MetroStation(name: "Frederiksberg Allé", coordinate: .init(latitude: 55.67362014867494, longitude: 12.540376294124172), lines: [.m1])
    static let akselMollersHave = MetroStation(name: "Aksel Møllers Have", coordinate: .init(latitude: 55.68628169743727, longitude: 12.533285341213658), lines: [.m1])
    static let nuuksplads = MetroStation(name: "Nuuks Plads", coordinate: .init(latitude: 55.688712986296935, longitude: 12.542844622705031), lines: [.m3])
    static let norrebrosRunddel = MetroStation(name: "Nørrebros Runddel", coordinate: .init(latitude: 55.693828654043685, longitude: 12.548904848677711), lines: [.m3])
    static let norrebro = MetroStation(name: "Nørrebro", coordinate: .init(latitude: 55.700697885828944, longitude: 12.53782431089072), lines: [.m3])
    static let skjoldsplads = MetroStation(name: "Skjoldsplads", coordinate: .init(latitude: 55.7034463945242, longitude: 12.548664126385635), lines: [.m3])
    static let vibenshusRunddel = MetroStation(name: "Vibenshus Runddel", coordinate: .init(latitude: 55.70636841587999, longitude: 12.564603249767464), lines: [.m3])
    static let poulHenningsenPlads = MetroStation(name: "Poul Henningsens Plads", coordinate: .init(latitude: 55.70946268908737, longitude: 12.57622193403667), lines: [.m3, .m4])
    static let trianglen = MetroStation(name: "Trianglen", coordinate: .init(latitude: 55.699191103674764, longitude: 12.575665448649952), lines: [.m3])

    // M4 only
    static let orientkaj = MetroStation(name: "Orientkaj", coordinate: .init(latitude: 55.71158528936026, longitude: 12.595274664000025), lines: [.m3, .m4])
    static let nordhavn = MetroStation(name: "Nordhavn", coordinate: .init(latitude: 55.70517914153733, longitude: 12.590949107561578), lines: [.m3, .m4])
    static let havneholmen = MetroStation(name: "Havneholmen", coordinate: .init(latitude: 55.660980471712534, longitude: 12.559319229182776), lines: [.m4])
    static let enghaveBrygge = MetroStation(name: "Enghave Brygge", coordinate: .init(latitude: 55.654046212044385, longitude: 12.556462494697978), lines: [.m4])
    static let sluseholmen = MetroStation(name: "Sluseholmen", coordinate: .init(latitude: 55.64585820398888, longitude: 12.544309643124919), lines: [.m3])
    static let mozartsPlads = MetroStation(name: "Mozarts Plads", coordinate: .init(latitude: 55.648968080889844, longitude: 12.53424213826741), lines: [.m3])
    static let kobenhavenS = MetroStation(name: "København Syd", coordinate: .init(latitude: 55.65277052596076, longitude: 12.515873785354557), lines: [.m4])
}
