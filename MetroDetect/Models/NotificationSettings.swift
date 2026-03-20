import Foundation

struct NotificationSettings: Equatable, Codable {
    // MARK: - Proximity Notifications

    var proximityEnabled: Bool
    var proximityRadius: Double // meters
    var proximityStationFilter: StationFilter

    enum StationFilter: Equatable, Codable {
        case all
        case selected(Set<String>) // station names
    }

    // MARK: - Movement Notifications

    var movementEnabled: Bool
    var minimumSpeedMPS: Double
    var maximumSpeedMPS: Double
    var sustainedDurationSeconds: TimeInterval
    var requireStartAtStation: Bool
    var movementCooldownMinutes: Double

    // MARK: - Defaults

    static let `default` = NotificationSettings(
        proximityEnabled: true,
        proximityRadius: 150,
        proximityStationFilter: .all,
        movementEnabled: true,
        minimumSpeedMPS: 40.0 / 3.6,
        maximumSpeedMPS: 90.0 / 3.6,
        sustainedDurationSeconds: 0,
        requireStartAtStation: false,
        movementCooldownMinutes: 60
    )

    // MARK: - km/h Convenience

    var minimumSpeedKMH: Double {
        get { minimumSpeedMPS * 3.6 }
        set { minimumSpeedMPS = newValue / 3.6 }
    }

    var maximumSpeedKMH: Double {
        get { maximumSpeedMPS * 3.6 }
        set { maximumSpeedMPS = newValue / 3.6 }
    }

    var movementCooldownSeconds: TimeInterval {
        movementCooldownMinutes * 60
    }

    // MARK: - Validation

    var isValid: Bool {
        proximityRadius > 0
            && minimumSpeedMPS > 0
            && maximumSpeedMPS > 0
            && minimumSpeedMPS <= maximumSpeedMPS
            && sustainedDurationSeconds >= 0
            && movementCooldownMinutes >= 0
            && {
                if case .selected(let stations) = proximityStationFilter {
                    return !stations.isEmpty
                }
                return true
            }()
    }
}

// MARK: - Codable

extension NotificationSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        proximityEnabled = try container.decode(Bool.self, forKey: .proximityEnabled)
        proximityRadius = try container.decode(Double.self, forKey: .proximityRadius)
        proximityStationFilter = try container.decode(StationFilter.self, forKey: .proximityStationFilter)
        movementEnabled = try container.decode(Bool.self, forKey: .movementEnabled)
        minimumSpeedMPS = try container.decode(Double.self, forKey: .minimumSpeedMPS)
        maximumSpeedMPS = try container.decode(Double.self, forKey: .maximumSpeedMPS)
        sustainedDurationSeconds = try container.decode(TimeInterval.self, forKey: .sustainedDurationSeconds)
        requireStartAtStation = try container.decode(Bool.self, forKey: .requireStartAtStation)
        movementCooldownMinutes = try container.decodeIfPresent(Double.self, forKey: .movementCooldownMinutes) ?? 60
    }
}

// MARK: - UserDefaults Persistence

extension NotificationSettings {
    private static let storageKey = "notificationSettings"

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func load(from defaults: UserDefaults = .standard) -> NotificationSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}
