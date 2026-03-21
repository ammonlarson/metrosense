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

    init(
        settings: NotificationSettings = .load(),
        currentLocation: CLLocation? = nil,
        currentSpeed: Double = 0,
        lastMovementNotificationTime: Date? = nil,
        onSettingsChanged: @escaping (NotificationSettings) -> Void = { $0.save() }
    ) {
        _settings = State(initialValue: settings)
        self.onSettingsChanged = onSettingsChanged
        self.currentLocation = currentLocation
        self.currentSpeed = currentSpeed
        self.lastMovementNotificationTime = lastMovementNotificationTime

        // Collect unique station names across all lines
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
                proximitySection
                movementSection
                testSection
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title2)
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

    // MARK: - Proximity Section

    private var proximitySection: some View {
        Section {
            Toggle("Enable Proximity Alerts", isOn: $settings.proximityEnabled)

            if settings.proximityEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        TextField("meters", value: $settings.proximityRadius, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                    Text("How close you must be to a station to trigger an alert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                StationFilterPickerView(
                    filter: $settings.proximityStationFilter,
                    allStationNames: allStationNames
                )
            }
        } header: {
            Text("Metro Proximity")
        } footer: {
            Text("Get notified when you are near a metro station.")
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section {
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
                // Proximity row: shows progress bar while testing, result when done
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
            Text("Test")
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
                lastMovementNotificationTime: lastMovementNotificationTime
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

    // MARK: - Movement Section

    private var movementSection: some View {
        Section {
            Toggle("Enable Movement Alerts", isOn: $settings.movementEnabled)

            if settings.movementEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Min Speed")
                        Spacer()
                        TextField("km/h", value: $settings.minimumSpeedKMH, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km/h")
                            .foregroundStyle(.secondary)
                    }
                    Text("Speeds below this are ignored (e.g. walking, cycling).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Speed")
                        Spacer()
                        TextField("km/h", value: $settings.maximumSpeedKMH, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km/h")
                            .foregroundStyle(.secondary)
                    }
                    Text("Speeds above this are ignored (e.g. cars on highways).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if settings.minimumSpeedMPS > settings.maximumSpeedMPS {
                    Text("Min speed must not exceed max speed.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sustained Duration")
                        Spacer()
                        TextField("sec", value: $settings.sustainedDurationSeconds, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("s")
                            .foregroundStyle(.secondary)
                    }
                    Text("How long speed must stay in range before an alert fires. Use 0 to alert immediately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                    Text("Minimum time between repeated movement alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Require Start at Station", isOn: $settings.requireStartAtStation)
                    Text("Only alert if movement began near a metro station.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let filter = Binding($settings.requireStartAtStationFilter) {
                    StationFilterPickerView(
                        filter: filter,
                        allStationNames: allStationNames,
                        pickerLabel: "Start Stations"
                    )
                }
            }
        } header: {
            Text("Movement Detection")
        } footer: {
            Text("Get notified when movement matching metro speed is detected.")
        }
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
        lastMovementNotificationTime: Date? = nil
    ) -> NotificationTestResult {
        // Evaluate proximity
        let proximityResult: (Bool, String)
        if !settings.proximityEnabled {
            proximityResult = (false, "Proximity alerts are disabled.")
        } else if let location {
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
        } else {
            proximityResult = (false, "Location unavailable.")
        }

        // Evaluate movement
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
                // Check requireStartAtStationFilter before reporting positive
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
