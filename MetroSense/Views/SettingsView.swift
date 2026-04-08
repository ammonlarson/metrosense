import SwiftUI
import CoreLocation

struct SettingsView: View {
    @State private var settings: NotificationSettings
    @State private var testResult: NotificationTestResult?
    @State private var isTesting: Bool = false
    @State private var testProgress: CGFloat = 0
    @State private var testRunId: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let allStationNames: [String]
    private let onSettingsChanged: (NotificationSettings) -> Void
    private let currentLocation: CLLocation?
    private let currentSpeed: Double
    private let lastMovementNotificationTime: Date?
    private let lastProximityNotificationTime: Date?

    init(
        settings: NotificationSettings = .load(),
        currentLocation: CLLocation? = nil,
        currentSpeed: Double = 0,
        lastMovementNotificationTime: Date? = nil,
        lastProximityNotificationTime: Date? = nil,
        onSettingsChanged: @escaping (NotificationSettings) -> Void = { $0.save() }
    ) {
        _settings = State(initialValue: settings)
        self.onSettingsChanged = onSettingsChanged
        self.currentLocation = currentLocation
        self.currentSpeed = currentSpeed
        self.lastMovementNotificationTime = lastMovementNotificationTime
        self.lastProximityNotificationTime = lastProximityNotificationTime

        var seen = Set<String>()
        var names: [String] = []
        for line in MetroLine.all {
            for station in line.stations {
                if seen.insert(station.name).inserted {
                    names.append(station.name)
                }
            }
        }
        allStationNames = names.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                categoriesSection
                notificationsSection
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onChange(of: settings) { _, newValue in
                if newValue.isValid {
                    onSettingsChanged(newValue)
                }
            }
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        Section {
            NavigationLink {
                ProximitySettingsView(
                    settings: $settings,
                    allStationNames: allStationNames
                )
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Metro Proximity")
                        Text(proximityStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "location.circle")
                        .foregroundStyle(.blue)
                }
            }

            NavigationLink {
                MovementSettingsView(
                    settings: $settings,
                    allStationNames: allStationNames
                )
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Movement Detection")
                        Text(movementStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Categories")
        }
    }

    private var proximityStatusText: String {
        settings.proximityEnabled ? "On — \(Int(settings.proximityRadius))m radius" : "Off"
    }

    private var movementStatusText: String {
        settings.movementEnabled ? "On — \(Int(settings.minimumSpeedKMH))–\(Int(settings.maximumSpeedKMH)) km/h" : "Off"
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cooldown")
                    Spacer()
                    TextField("min", value: $settings.movementCooldownMinutes, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
                Text("Minimum time between repeated alerts (applies to both proximity and movement).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                runTest()
            } label: {
                HStack {
                    Label("Test Notifications Now", systemImage: "bell.badge")
                    Spacer()
                }
            }
            .disabled(!settings.isValid || isTesting)

            if isTesting || testResult != nil {
                if isTesting {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * testProgress)
                                .animation(.linear(duration: 1.5), value: testProgress)
                        }
                    }
                    .id(testRunId)
                    .frame(height: 12)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else if let result = testResult {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.proximityState.icon)
                            .foregroundStyle(result.proximityState.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.proximityState.label(for: "Proximity"))
                                .foregroundStyle(.primary)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let result = testResult {
                    Group {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: result.movementState.icon)
                                .foregroundStyle(result.movementState.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.movementState.label(for: "Movement"))
                                    .foregroundStyle(.primary)
                                Text(result.movementDetail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .id("testMovementResult")
                    .opacity(isTesting ? 0 : 1)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Check whether a notification would fire right now based on your current location and speed.")
        }
    }

    private func runTest() {
        testResult = nil
        testProgress = 0
        testRunId += 1
        isTesting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            testProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            let result = NotificationTestResult.evaluate(
                settings: settings,
                location: currentLocation,
                speed: currentSpeed,
                lastMovementNotificationTime: lastMovementNotificationTime,
                lastProximityNotificationTime: lastProximityNotificationTime
            )
            withAnimation {
                testResult = result
                isTesting = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scrollFormToBottom()
            }
        }
    }

    private func scrollFormToBottom() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let scrollView = findScrollView(in: window) else { return }
        let bottomOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
        )
        scrollView.setContentOffset(bottomOffset, animated: true)
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }
}

// MARK: - Notification Test Result

enum NotificationTestFireState: Equatable {
    case wouldFire
    case wouldNotFire
    case cooldownBlocked(remaining: TimeInterval)

    var icon: String {
        switch self {
        case .wouldFire: "checkmark.circle.fill"
        case .wouldNotFire: "xmark.circle.fill"
        case .cooldownBlocked: "clock.badge.exclamationmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .wouldFire: .green
        case .wouldNotFire: .red
        case .cooldownBlocked: .orange
        }
    }

    func label(for category: String) -> String {
        switch self {
        case .wouldFire:
            return "\(category): Would fire"
        case .wouldNotFire:
            return "\(category): Would not fire"
        case .cooldownBlocked(let remaining):
            let mins = Int(remaining / 60)
            let secs = Int(remaining.truncatingRemainder(dividingBy: 60))
            return "\(category): Blocked by cooldown (\(mins)m \(secs)s remaining)"
        }
    }
}

struct NotificationTestResult: Equatable {
    let timestamp: Date
    let proximityState: NotificationTestFireState
    let proximityDetail: String
    let movementState: NotificationTestFireState
    let movementDetail: String

    static func evaluate(
        settings: NotificationSettings,
        location: CLLocation?,
        speed: Double,
        lastMovementNotificationTime: Date? = nil,
        lastProximityNotificationTime: Date? = nil
    ) -> NotificationTestResult {
        let proximityState: NotificationTestFireState
        let proximityDetail: String

        if !settings.proximityEnabled {
            proximityState = .wouldNotFire
            proximityDetail = "Proximity alerts are disabled."
        } else if let location {
            let cooldownRemaining = Self.cooldownRemaining(
                cooldownSeconds: settings.movementCooldownSeconds,
                lastNotificationTime: lastProximityNotificationTime
            )

            let accuracy = location.horizontalAccuracy
            let allStations = MetroLine.all.flatMap { $0.stations }

            if accuracy > settings.proximityRadius {
                proximityState = .wouldNotFire
                let closest = allStations.min { $0.distance(from: location) < $1.distance(from: location) }
                if let closest {
                    let dist = Int(closest.distance(from: location))
                    proximityDetail = "GPS accuracy (±\(Int(accuracy))m) exceeds radius (\(Int(settings.proximityRadius))m). Nearest: \(closest.name) (\(dist)m). Proximity skipped."
                } else {
                    proximityDetail = "GPS accuracy (±\(Int(accuracy))m) exceeds radius (\(Int(settings.proximityRadius))m). Proximity skipped."
                }
            } else {
                let stationsInRange = allStations.filter {
                    ($0.distance(from: location) + accuracy) <= settings.proximityRadius
                }

                if stationsInRange.isEmpty {
                    proximityState = .wouldNotFire
                    let closest = allStations.min { $0.distance(from: location) < $1.distance(from: location) }
                    if let closest {
                        let dist = Int(closest.distance(from: location))
                        proximityDetail = "No stations within \(Int(settings.proximityRadius))m (±\(Int(accuracy))m accuracy). Nearest: \(closest.name) (\(dist)m away)."
                    } else {
                        proximityDetail = "No stations within \(Int(settings.proximityRadius))m."
                    }
                } else {
                    let matchingStations: [MetroStation]
                    switch settings.proximityStationFilter {
                    case .all:
                        matchingStations = stationsInRange
                    case .selected(let names):
                        matchingStations = stationsInRange.filter { names.contains($0.name) }
                    }

                    if matchingStations.isEmpty {
                        proximityState = .wouldNotFire
                        let inRangeNames = stationsInRange.map(\.name).joined(separator: ", ")
                        proximityDetail = "Stations in range (\(inRangeNames)) are not in your selected filter."
                    } else {
                        let names = matchingStations.map(\.name).joined(separator: ", ")
                        if let remaining = cooldownRemaining {
                            proximityState = .cooldownBlocked(remaining: remaining)
                            proximityDetail = "Near: \(names). Would fire, but cooldown is active."
                        } else {
                            proximityState = .wouldFire
                            proximityDetail = "Near: \(names)"
                        }
                    }
                }
            }
        } else {
            proximityState = .wouldNotFire
            proximityDetail = "Location unavailable."
        }

        let movementState: NotificationTestFireState
        let movementDetail: String

        if !settings.movementEnabled {
            movementState = .wouldNotFire
            movementDetail = "Movement alerts are disabled."
        } else {
            let speedKMH = String(format: "%.1f", speed * 3.6)
            let inRange = speed >= settings.minimumSpeedMPS && speed <= settings.maximumSpeedMPS

            let cooldownRemaining = Self.cooldownRemaining(
                cooldownSeconds: settings.movementCooldownSeconds,
                lastNotificationTime: lastMovementNotificationTime
            )

            if !inRange {
                movementState = .wouldNotFire
                if speed < settings.minimumSpeedMPS {
                    movementDetail = "Speed \(speedKMH) km/h is below minimum (\(String(format: "%.0f", settings.minimumSpeedKMH)) km/h)."
                } else {
                    movementDetail = "Speed \(speedKMH) km/h is above maximum (\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h)."
                }
            } else if let filter = settings.requireStartAtStationFilter {
                let allStations = MetroLine.all.flatMap { $0.stations }
                let nearbyStations: [MetroStation]
                if let loc = location {
                    nearbyStations = allStations.filter { $0.isNearby(loc) }
                } else {
                    nearbyStations = []
                }

                let stationCheckPassed: Bool
                let stationDetail: String

                switch filter {
                case .all:
                    if nearbyStations.isEmpty {
                        stationCheckPassed = false
                        stationDetail = "Speed \(speedKMH) km/h is within metro range but \"Require start at station\" is enabled and you are not near any station."
                    } else {
                        stationCheckPassed = true
                        let stationNames = nearbyStations.map(\.name).joined(separator: ", ")
                        stationDetail = "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h). Near station: \(stationNames)."
                    }
                case .selected(let names):
                    let matching = nearbyStations.filter { names.contains($0.name) }
                    if matching.isEmpty {
                        stationCheckPassed = false
                        if nearbyStations.isEmpty {
                            stationDetail = "Speed \(speedKMH) km/h is within metro range but \"Require start at station\" is enabled with a station filter, and you are not near any station."
                        } else {
                            let nearbyNames = nearbyStations.map(\.name).joined(separator: ", ")
                            stationDetail = "Speed \(speedKMH) km/h is within metro range but nearby stations (\(nearbyNames)) are not in the required start-station filter."
                        }
                    } else {
                        stationCheckPassed = true
                        let stationNames = matching.map(\.name).joined(separator: ", ")
                        stationDetail = "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h). Near selected station: \(stationNames)."
                    }
                }

                if stationCheckPassed {
                    if let remaining = cooldownRemaining {
                        movementState = .cooldownBlocked(remaining: remaining)
                        movementDetail = "\(stationDetail) Would fire, but cooldown is active."
                    } else {
                        movementState = .wouldFire
                        movementDetail = stationDetail
                    }
                } else {
                    movementState = .wouldNotFire
                    movementDetail = stationDetail
                }
            } else {
                let detail = "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h)."
                if let remaining = cooldownRemaining {
                    movementState = .cooldownBlocked(remaining: remaining)
                    movementDetail = "\(detail) Would fire, but cooldown is active."
                } else {
                    movementState = .wouldFire
                    movementDetail = detail
                }
            }
        }

        return NotificationTestResult(
            timestamp: Date(),
            proximityState: proximityState,
            proximityDetail: proximityDetail,
            movementState: movementState,
            movementDetail: movementDetail
        )
    }

    private static func cooldownRemaining(
        cooldownSeconds: TimeInterval,
        lastNotificationTime: Date?
    ) -> TimeInterval? {
        guard cooldownSeconds > 0, let lastTime = lastNotificationTime else {
            return nil
        }
        let elapsed = Date().timeIntervalSince(lastTime)
        let remaining = cooldownSeconds - elapsed
        return remaining > 0 ? remaining : nil
    }
}

#Preview {
    SettingsView()
}
