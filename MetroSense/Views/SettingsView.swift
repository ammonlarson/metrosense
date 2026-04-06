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
                        Image(systemName: result.proximityWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.proximityWouldFire ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.proximityWouldFire ? "Proximity: Would fire" : "Proximity: Would not fire")
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
                            Image(systemName: result.movementWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.movementWouldFire ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.movementWouldFire ? "Movement: Would fire" : "Movement: Would not fire")
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

struct NotificationTestResult: Equatable {
    let timestamp: Date
    let proximityWouldFire: Bool
    let proximityDetail: String
    let movementWouldFire: Bool
    let movementDetail: String

    static func evaluate(
        settings: NotificationSettings,
        location: CLLocation?,
        speed: Double,
        lastMovementNotificationTime: Date? = nil,
        lastProximityNotificationTime: Date? = nil
    ) -> NotificationTestResult {
        let proximityResult: (Bool, String)
        if !settings.proximityEnabled {
            proximityResult = (false, "Proximity alerts are disabled.")
        } else if let location {
            let proximityCooldownElapsed: Bool
            var proximityCooldownNote = ""
            if settings.movementCooldownSeconds > 0, let lastTime = lastProximityNotificationTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                let remaining = settings.movementCooldownSeconds - elapsed
                if remaining > 0 {
                    proximityCooldownElapsed = false
                    let mins = Int(remaining / 60)
                    let secs = Int(remaining.truncatingRemainder(dividingBy: 60))
                    proximityCooldownNote = " Cooldown active (\(mins)m \(secs)s remaining)."
                } else {
                    proximityCooldownElapsed = true
                }
            } else {
                proximityCooldownElapsed = true
            }

            if !proximityCooldownElapsed {
                proximityResult = (false, "Proximity alerts suppressed by cooldown.\(proximityCooldownNote)")
            } else {
            let accuracy = location.horizontalAccuracy
            let allStations = MetroLine.all.flatMap { $0.stations }

            if accuracy > settings.proximityRadius {
                let closest = allStations.min { $0.distance(from: location) < $1.distance(from: location) }
                let detail: String
                if let closest {
                    let dist = Int(closest.distance(from: location))
                    detail = "GPS accuracy (±\(Int(accuracy))m) exceeds radius (\(Int(settings.proximityRadius))m). Nearest: \(closest.name) (\(dist)m). Proximity skipped."
                } else {
                    detail = "GPS accuracy (±\(Int(accuracy))m) exceeds radius (\(Int(settings.proximityRadius))m). Proximity skipped."
                }
                proximityResult = (false, detail)
            } else {
                let stationsInRange = allStations.filter {
                    ($0.distance(from: location) + accuracy) <= settings.proximityRadius
                }

                if stationsInRange.isEmpty {
                    let closest = allStations.min { $0.distance(from: location) < $1.distance(from: location) }
                    let detail: String
                    if let closest {
                        let dist = Int(closest.distance(from: location))
                        detail = "No stations within \(Int(settings.proximityRadius))m (±\(Int(accuracy))m accuracy). Nearest: \(closest.name) (\(dist)m away)."
                    } else {
                        detail = "No stations within \(Int(settings.proximityRadius))m."
                    }
                    proximityResult = (false, detail)
                } else {
                    let matchingStations: [MetroStation]
                    switch settings.proximityStationFilter {
                    case .all:
                        matchingStations = stationsInRange
                    case .selected(let names):
                        matchingStations = stationsInRange.filter { names.contains($0.name) }
                    }

                    if matchingStations.isEmpty {
                        let inRangeNames = stationsInRange.map(\.name).joined(separator: ", ")
                        proximityResult = (false, "Stations in range (\(inRangeNames)) are not in your selected filter.")
                    } else {
                        let names = matchingStations.map(\.name).joined(separator: ", ")
                        proximityResult = (true, "Near: \(names)")
                    }
                }
            }
            }
        } else {
            proximityResult = (false, "Location unavailable.")
        }

        let movementResult: (Bool, String)
        if !settings.movementEnabled {
            movementResult = (false, "Movement alerts are disabled.")
        } else {
            let speedKMH = String(format: "%.1f", speed * 3.6)
            let inRange = speed >= settings.minimumSpeedMPS && speed <= settings.maximumSpeedMPS

            let cooldownElapsed: Bool
            var cooldownNote = ""
            if settings.movementCooldownSeconds > 0, let lastTime = lastMovementNotificationTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                let remaining = settings.movementCooldownSeconds - elapsed
                if remaining > 0 {
                    cooldownElapsed = false
                    let mins = Int(remaining / 60)
                    let secs = Int(remaining.truncatingRemainder(dividingBy: 60))
                    cooldownNote = " Cooldown active (\(mins)m \(secs)s remaining)."
                } else {
                    cooldownElapsed = true
                }
            } else {
                cooldownElapsed = true
            }

            if inRange && !cooldownElapsed {
                movementResult = (false, "Speed \(speedKMH) km/h is within metro range but suppressed by cooldown.\(cooldownNote)")
            } else if inRange {
                if let filter = settings.requireStartAtStationFilter {
                    let allStations = MetroLine.all.flatMap { $0.stations }
                    let nearbyStations: [MetroStation]
                    if let loc = location {
                        nearbyStations = allStations.filter { $0.isNearby(loc) }
                    } else {
                        nearbyStations = []
                    }

                    switch filter {
                    case .all:
                        if nearbyStations.isEmpty {
                            movementResult = (false, "Speed \(speedKMH) km/h is within metro range but \"Require start at station\" is enabled and you are not near any station.")
                        } else {
                            let stationNames = nearbyStations.map(\.name).joined(separator: ", ")
                            movementResult = (true, "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h). Near station: \(stationNames).")
                        }
                    case .selected(let names):
                        let matching = nearbyStations.filter { names.contains($0.name) }
                        if matching.isEmpty {
                            if nearbyStations.isEmpty {
                                movementResult = (false, "Speed \(speedKMH) km/h is within metro range but \"Require start at station\" is enabled with a station filter, and you are not near any station.")
                            } else {
                                let nearbyNames = nearbyStations.map(\.name).joined(separator: ", ")
                                movementResult = (false, "Speed \(speedKMH) km/h is within metro range but nearby stations (\(nearbyNames)) are not in the required start-station filter.")
                            }
                        } else {
                            let stationNames = matching.map(\.name).joined(separator: ", ")
                            movementResult = (true, "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h). Near selected station: \(stationNames).")
                        }
                    }
                } else {
                    movementResult = (true, "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedKMH))–\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h).")
                }
            } else if speed < settings.minimumSpeedMPS {
                movementResult = (false, "Speed \(speedKMH) km/h is below minimum (\(String(format: "%.0f", settings.minimumSpeedKMH)) km/h).")
            } else {
                movementResult = (false, "Speed \(speedKMH) km/h is above maximum (\(String(format: "%.0f", settings.maximumSpeedKMH)) km/h).")
            }
        }

        return NotificationTestResult(
            timestamp: Date(),
            proximityWouldFire: proximityResult.0,
            proximityDetail: proximityResult.1,
            movementWouldFire: movementResult.0,
            movementDetail: movementResult.1
        )
    }
}

#Preview {
    SettingsView()
}
