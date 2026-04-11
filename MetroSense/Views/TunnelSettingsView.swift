import SwiftUI

struct TunnelSettingsView: View {
    @Binding var settings: NotificationSettings
    let allStationNames: [String]

    var body: some View {
        Form {
            Section {
                Toggle("Enable Tunnel Detection", isOn: $settings.tunnelDetectionEnabled)
                    .tint(.blue)

                if settings.tunnelDetectionEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Tunnel Notifications", isOn: $settings.tunnelNotificationsEnabled)
                            .tint(.blue)
                        Text("Notify when you may be traveling in a metro tunnel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sustained Duration")
                            Spacer()
                            TextField("sec", value: $settings.tunnelSustainedDurationSeconds, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("s")
                                .foregroundStyle(.secondary)
                        }
                        Text("How long GPS signal must be lost before inferring tunnel travel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Restrict to Entry Points", isOn: $settings.tunnelEntryPointsEnabled)
                            .tint(.blue)
                        Text("Only detect tunnels at known entry points or selected stations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let filter = Binding($settings.tunnelEntryPointFilter) {
                        StationFilterPickerView(
                            filter: filter,
                            allStationNames: tunnelEntryPointNames,
                            pickerLabel: "Entry Points"
                        )
                    }
                }
            } header: {
                Text("Infer metro tunnel travel when GPS signal is lost near a station.")
            }
        }
        .navigationTitle("Tunnel Detection")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tunnelEntryPointNames: [String] {
        allStationNames.filter { MetroStation.tunnelEntryPoints.contains($0) }
    }
}

#Preview {
    NavigationStack {
        TunnelSettingsView(
            settings: .constant(.load()),
            allStationNames: ["Kongens Nytorv", "Norreport"]
        )
    }
}
