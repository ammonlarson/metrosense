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
    let isCircular: Bool

    var name: String { id.rawValue }

    init(id: LineID, stations: [MetroStation], isCircular: Bool = false) {
        self.id = id
        self.stations = stations
        self.isCircular = isCircular
    }
}

// MARK: - Copenhagen Metro Data

extension MetroLine {
    // Speed thresholds in m/s
    // Copenhagen Metro runs ~40–80 km/h between stations
    static let minimumSpeedKMH: Double = 40.0
    static let maximumSpeedKMH: Double = 90.0
    static let minimumSpeedMPS: Double = minimumSpeedKMH / 3.6
    static let maximumSpeedMPS: Double = maximumSpeedKMH / 3.6

    static let all: [MetroLine] = [m1, m2, m3, m4]

    static let m1 = MetroLine(id: .m1, stations: [
        .vanlose,
        .flintholm,
        .lindevang,
        .fasanvej,
        .frederiksberg,
        .forum,
        .norreport,
        .kongensNytorv,
        .christianshavn,
        .islandsBrygge,
        .drByen,
        .sundby,
        .bellaCenter,
        .orestad,
        .vestamager,
    ])

    static let m2 = MetroLine(id: .m2, stations: [
        .vanlose,
        .flintholm,
        .lindevang,
        .fasanvej,
        .frederiksberg,
        .forum,
        .norreport,
        .kongensNytorv,
        .christianshavn,
        .amagerbro,
        .lergravsparken,
        .oresund,
        .amagerstrand,
        .femoren,
        .kastrup,
        .kobenhavnAirport,
    ])

    static let m3 = MetroLine(id: .m3, stations: [
        .osterport,
        .marmorkirken,
        .kongensNytorv,
        .gammelStrand,
        .radhuspladsen,
        .kobenhavnH,
        .enghavePlads,
        .frederiksbergAlle,
        .frederiksberg,
        .akselMollersHave,
        .nuuksplads,
        .norrebrosRunddel,
        .norrebro,
        .skjoldsplads,
        .vibenshusRunddel,
        .poulHenningsenPlads,
        .trianglen,
    ], isCircular: true)

    static let m4 = MetroLine(id: .m4, stations: [
        .orientkaj,
        .nordhavn,
        .osterport,
        .marmorkirken,
        .kongensNytorv,
        .gammelStrand,
        .radhuspladsen,
        .kobenhavnH,
        .havneholmen,
        .enghaveBrygge,
        .sluseholmen,
        .mozartsPlads,
        .kobenhavenS,
    ])
}
