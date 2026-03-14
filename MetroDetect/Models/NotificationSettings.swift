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

    // MARK: - Defaults

    static let `default` = NotificationSettings(
        proximityEnabled: true,
        proximityRadius: 150,
        proximityStationFilter: .all,
        movementEnabled: true,
        minimumSpeedMPS: 8.0,
        maximumSpeedMPS: 25.0,
        sustainedDurationSeconds: 0,
        requireStartAtStation: false
    )

    // MARK: - Validation

    var isValid: Bool {
        proximityRadius > 0
            && minimumSpeedMPS > 0
            && maximumSpeedMPS > 0
            && minimumSpeedMPS <= maximumSpeedMPS
            && sustainedDurationSeconds >= 0
            && {
                if case .selected(let stations) = proximityStationFilter {
                    return !stations.isEmpty
                }
                return true
            }()
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
