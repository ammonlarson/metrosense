import SwiftUI

struct MovementSettingsView: View {
    @Binding var settings: NotificationSettings
    let allStationNames: [String]

    var body: some View {
        Form {
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
            } footer: {
                Text("Get notified when movement matching metro speed is detected.")
            }
        }
        .navigationTitle("Movement Detection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MovementSettingsView(
            settings: .constant(.load()),
            allStationNames: ["Kongens Nytorv", "Nørreport"]
        )
    }
}
