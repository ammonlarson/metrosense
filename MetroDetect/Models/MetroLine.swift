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

    ])

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
