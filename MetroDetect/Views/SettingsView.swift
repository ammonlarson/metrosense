import SwiftUI

struct SettingsView: View {
    @State private var settings: NotificationSettings
    @Environment(\.dismiss) private var dismiss

    private let allStationNames: [String]
    private let onSave: (NotificationSettings) -> Void

    init(settings: NotificationSettings = .load(), onSave: @escaping (NotificationSettings) -> Void = { $0.save() }) {
        _settings = State(initialValue: settings)
        self.onSave = onSave

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
                    : .selected(Set(allStationNames))
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

#Preview {
    SettingsView()
}
