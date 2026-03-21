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
    var requireStartAtStationFilter: StationFilter?
    var movementCooldownMinutes: Double

    // MARK: - Defaults

    static let `default` = NotificationSettings(
        proximityEnabled: true,
        proximityRadius: 150,
        proximityStationFilter: .all,
        movementEnabled: true,
        minimumSpeedMPS: 40.0 / 3.6,
        maximumSpeedMPS: 90.0 / 3.6,
        sustainedDurationSeconds: 10,
        requireStartAtStationFilter: nil,
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

    var requireStartAtStation: Bool {
        get { requireStartAtStationFilter != nil }
        set {
            if newValue {
                requireStartAtStationFilter = requireStartAtStationFilter ?? .all
            } else {
                requireStartAtStationFilter = nil
            }
        }
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
            && {
                if case .selected(let stations) = requireStartAtStationFilter {
                    return !stations.isEmpty
                }
                return true
            }()
    }
}

// MARK: - Codable

extension NotificationSettings {
    private enum CodingKeys: String, CodingKey {
        case proximityEnabled
        case proximityRadius
        case proximityStationFilter
        case movementEnabled
        case minimumSpeedMPS
        case maximumSpeedMPS
        case sustainedDurationSeconds
        case requireStartAtStationFilter
        case requireStartAtStation // legacy key for backward compat
        case movementCooldownMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        proximityEnabled = try container.decode(Bool.self, forKey: .proximityEnabled)
        proximityRadius = try container.decode(Double.self, forKey: .proximityRadius)
        proximityStationFilter = try container.decode(StationFilter.self, forKey: .proximityStationFilter)
        movementEnabled = try container.decode(Bool.self, forKey: .movementEnabled)
        minimumSpeedMPS = try container.decode(Double.self, forKey: .minimumSpeedMPS)
        maximumSpeedMPS = try container.decode(Double.self, forKey: .maximumSpeedMPS)
        sustainedDurationSeconds = try container.decode(TimeInterval.self, forKey: .sustainedDurationSeconds)
        // Backward compatibility: previously stored as Bool (`requireStartAtStation`),
        // now StationFilter? (`requireStartAtStationFilter`).
        if container.contains(.requireStartAtStationFilter) {
            requireStartAtStationFilter = try container.decodeIfPresent(StationFilter.self, forKey: .requireStartAtStationFilter)
        } else if let legacy = try container.decodeIfPresent(Bool.self, forKey: .requireStartAtStation) {
            requireStartAtStationFilter = legacy ? .all : nil
        } else {
            requireStartAtStationFilter = nil
        }
        movementCooldownMinutes = try container.decodeIfPresent(Double.self, forKey: .movementCooldownMinutes) ?? 60
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(proximityEnabled, forKey: .proximityEnabled)
        try container.encode(proximityRadius, forKey: .proximityRadius)
        try container.encode(proximityStationFilter, forKey: .proximityStationFilter)
        try container.encode(movementEnabled, forKey: .movementEnabled)
        try container.encode(minimumSpeedMPS, forKey: .minimumSpeedMPS)
        try container.encode(maximumSpeedMPS, forKey: .maximumSpeedMPS)
        try container.encode(sustainedDurationSeconds, forKey: .sustainedDurationSeconds)
        try container.encodeIfPresent(requireStartAtStationFilter, forKey: .requireStartAtStationFilter)
        try container.encode(movementCooldownMinutes, forKey: .movementCooldownMinutes)
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
