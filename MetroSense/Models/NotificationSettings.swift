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

    // MARK: - Tunnel Detection

    var tunnelDetectionEnabled: Bool
    var tunnelNotificationsEnabled: Bool
    var tunnelSustainedDurationSeconds: TimeInterval
    var tunnelEntryPointFilter: StationFilter?

    // MARK: - Rejsekort

    var rejsekortEnabled: Bool
    var alwaysShowRejsekortPill: Bool
    var proximityShowRejsekortPill: Bool
    var movementShowRejsekortPill: Bool
    var proximityRejsekortAction: Bool
    var movementRejsekortAction: Bool

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
        movementCooldownMinutes: 60,
        tunnelDetectionEnabled: false,
        tunnelNotificationsEnabled: true,
        tunnelSustainedDurationSeconds: 30,
        tunnelEntryPointFilter: nil,
        rejsekortEnabled: true,
        alwaysShowRejsekortPill: false,
        proximityShowRejsekortPill: true,
        movementShowRejsekortPill: true,
        proximityRejsekortAction: true,
        movementRejsekortAction: true
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

    var tunnelEntryPointsEnabled: Bool {
        get { tunnelEntryPointFilter != nil }
        set {
            if newValue {
                tunnelEntryPointFilter = tunnelEntryPointFilter ?? .all
            } else {
                tunnelEntryPointFilter = nil
            }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        proximityRadius > 0
            && minimumSpeedMPS > 0
            && maximumSpeedMPS > 0
            && minimumSpeedMPS <= maximumSpeedMPS
            && sustainedDurationSeconds >= 0
            && movementCooldownMinutes >= 0
            && tunnelSustainedDurationSeconds >= 0
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
            && {
                if case .selected(let stations) = tunnelEntryPointFilter {
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
        case tunnelDetectionEnabled
        case tunnelNotificationsEnabled
        case tunnelSustainedDurationSeconds
        case tunnelEntryPointFilter
        case rejsekortEnabled
        case alwaysShowRejsekortPill
        case proximityShowRejsekortPill
        case movementShowRejsekortPill
        case proximityRejsekortAction
        case movementRejsekortAction
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
        tunnelDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .tunnelDetectionEnabled) ?? false
        tunnelNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tunnelNotificationsEnabled) ?? true
        tunnelSustainedDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .tunnelSustainedDurationSeconds) ?? 30
        tunnelEntryPointFilter = try container.decodeIfPresent(StationFilter.self, forKey: .tunnelEntryPointFilter)
        rejsekortEnabled = try container.decodeIfPresent(Bool.self, forKey: .rejsekortEnabled) ?? true
        alwaysShowRejsekortPill = try container.decodeIfPresent(Bool.self, forKey: .alwaysShowRejsekortPill) ?? false
        proximityShowRejsekortPill = try container.decodeIfPresent(Bool.self, forKey: .proximityShowRejsekortPill) ?? true
        movementShowRejsekortPill = try container.decodeIfPresent(Bool.self, forKey: .movementShowRejsekortPill) ?? true
        proximityRejsekortAction = try container.decodeIfPresent(Bool.self, forKey: .proximityRejsekortAction) ?? true
        movementRejsekortAction = try container.decodeIfPresent(Bool.self, forKey: .movementRejsekortAction) ?? true
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
        try container.encode(tunnelDetectionEnabled, forKey: .tunnelDetectionEnabled)
        try container.encode(tunnelNotificationsEnabled, forKey: .tunnelNotificationsEnabled)
        try container.encode(tunnelSustainedDurationSeconds, forKey: .tunnelSustainedDurationSeconds)
        try container.encodeIfPresent(tunnelEntryPointFilter, forKey: .tunnelEntryPointFilter)
        try container.encode(rejsekortEnabled, forKey: .rejsekortEnabled)
        try container.encode(alwaysShowRejsekortPill, forKey: .alwaysShowRejsekortPill)
        try container.encode(proximityShowRejsekortPill, forKey: .proximityShowRejsekortPill)
        try container.encode(movementShowRejsekortPill, forKey: .movementShowRejsekortPill)
        try container.encode(proximityRejsekortAction, forKey: .proximityRejsekortAction)
        try container.encode(movementRejsekortAction, forKey: .movementRejsekortAction)
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
