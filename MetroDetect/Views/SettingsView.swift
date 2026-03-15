import SwiftUI
import CoreLocation

struct SettingsView: View {
    @State private var settings: NotificationSettings
    @State private var testResult: NotificationTestResult?
    @State private var testRunCount: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let allStationNames: [String]
    private let onSave: (NotificationSettings) -> Void
    private let currentLocation: CLLocation?
    private let currentSpeed: Double

    init(
        settings: NotificationSettings = .load(),
        currentLocation: CLLocation? = nil,
        currentSpeed: Double = 0,
        onSave: @escaping (NotificationSettings) -> Void = { $0.save() }
    ) {
        _settings = State(initialValue: settings)
        self.onSave = onSave
        self.currentLocation = currentLocation
        self.currentSpeed = currentSpeed

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(settings)
                        dismiss()
                    }
                    .disabled(!settings.isValid)
                }
            }
        }
    }

    // MARK: - Proximity Section

    private var proximitySection: some View {
        Section {
            Toggle("Enable Proximity Alerts", isOn: $settings.proximityEnabled)

            if settings.proximityEnabled {
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

                stationFilterPicker
            }
        } header: {
            Text("Metro Proximity")
        } footer: {
            Text("Get notified when you are near a metro station.")
        }
    }

    private var stationFilterPicker: some View {
        Group {
            Picker("Stations", selection: stationFilterBinding) {
                Text("All Stations").tag(true)
                Text("Selected Stations").tag(false)
            }

            if case .selected(let selected) = settings.proximityStationFilter {
                if selected.isEmpty {
                    Text("Select at least one station.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(allStationNames, id: \.self) { name in
                    Button {
                        toggleStation(name, in: selected)
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected.contains(name) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    private var stationFilterBinding: Binding<Bool> {
        Binding(
            get: {
                if case .all = settings.proximityStationFilter { return true }
                return false
            },
            set: { isAll in
                settings.proximityStationFilter = isAll
                    ? .all
                    : .selected(Set())
            }
        )
    }

    private func toggleStation(_ name: String, in selected: Set<String>) {
        var updated = selected
        if updated.contains(name) {
            updated.remove(name)
        } else {
            updated.insert(name)
        }
        settings.proximityStationFilter = .selected(updated)
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section {
            Button {
                testRunCount += 1
                testResult = NotificationTestResult.evaluate(
                    settings: settings,
                    location: currentLocation,
                    speed: currentSpeed,
                    runNumber: testRunCount
                )
            } label: {
                Label("Test Notifications Now", systemImage: "bell.badge")
            }
            .disabled(!settings.isValid)

            if let result = testResult {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                    Text("Run #\(result.runNumber)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.timestamp, style: .time)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if result.proximityWouldFire {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proximity: Would fire")
                                .foregroundStyle(.primary)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proximity: Would not fire")
                                .foregroundStyle(.primary)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if result.movementWouldFire {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Movement: Would fire")
                                .foregroundStyle(.primary)
                            Text(result.movementDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Movement: Would not fire")
                                .foregroundStyle(.primary)
                            Text(result.movementDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Text("Test")
        } footer: {
            Text("Check whether a notification would fire right now based on your current location and speed.")
        }
    }

    // MARK: - Movement Section

    private var movementSection: some View {
        Section {
            Toggle("Enable Movement Alerts", isOn: $settings.movementEnabled)

            if settings.movementEnabled {
                HStack {
                    Text("Min Speed")
                    Spacer()
                    TextField("m/s", value: $settings.minimumSpeedMPS, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m/s")
                        .foregroundStyle(.secondary)
                }

                Text("\(String(format: "%.1f", settings.minimumSpeedMPS * 3.6)) km/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Max Speed")
                    Spacer()
                    TextField("m/s", value: $settings.maximumSpeedMPS, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m/s")
                        .foregroundStyle(.secondary)
                }

                Text("\(String(format: "%.1f", settings.maximumSpeedMPS * 3.6)) km/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.minimumSpeedMPS > settings.maximumSpeedMPS {
                    Text("Min speed must not exceed max speed.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

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

                Toggle("Require Start at Station", isOn: $settings.requireStartAtStation)
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
    let runNumber: Int
    let timestamp: Date
    let proximityWouldFire: Bool
    let proximityDetail: String
    let movementWouldFire: Bool
    let movementDetail: String

    static func evaluate(
        settings: NotificationSettings,
        location: CLLocation?,
        speed: Double,
        runNumber: Int
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
            if inRange {
                movementResult = (true, "Speed \(speedKMH) km/h is within metro range (\(String(format: "%.0f", settings.minimumSpeedMPS * 3.6))–\(String(format: "%.0f", settings.maximumSpeedMPS * 3.6)) km/h).")
            } else if speed < settings.minimumSpeedMPS {
                movementResult = (false, "Speed \(speedKMH) km/h is below minimum (\(String(format: "%.0f", settings.minimumSpeedMPS * 3.6)) km/h).")
            } else {
                movementResult = (false, "Speed \(speedKMH) km/h is above maximum (\(String(format: "%.0f", settings.maximumSpeedMPS * 3.6)) km/h).")
            }
        }

        return NotificationTestResult(
            runNumber: runNumber,
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
