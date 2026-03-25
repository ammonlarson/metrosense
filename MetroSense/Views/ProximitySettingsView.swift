import SwiftUI

struct ProximitySettingsView: View {
    @Binding var settings: NotificationSettings
    let allStationNames: [String]

    var body: some View {
        Form {
            Section {
                Toggle("Enable Proximity Alerts", isOn: $settings.proximityEnabled)
                    .tint(.blue)

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
                Text("Get notified when you are near a metro station.")
            }
        }
        .navigationTitle("Metro Proximity")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProximitySettingsView(
            settings: .constant(.load()),
            allStationNames: ["Kongens Nytorv", "Nørreport"]
        )
    }
}
