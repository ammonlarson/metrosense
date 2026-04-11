import SwiftUI

struct RejsekortSettingsView: View {
    @Binding var settings: NotificationSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enable Rejsekort Integration", isOn: $settings.rejsekortEnabled)
                    .tint(.blue)
            } header: {
                Text("Quickly open the Rejsekort app from MetroSense when near a station or traveling on the metro.")
            }

            if settings.rejsekortEnabled {
                Section {
                    Toggle("Always Show", isOn: $settings.alwaysShowRejsekortPill)
                        .tint(.blue)
                    if !settings.alwaysShowRejsekortPill {
                        Toggle("Metro Proximity", isOn: $settings.proximityShowRejsekortPill)
                            .tint(.blue)
                        Toggle("Movement Detection", isOn: $settings.movementShowRejsekortPill)
                            .tint(.blue)
                    }
                } header: {
                    Text("In App")
                } footer: {
                    Text(settings.alwaysShowRejsekortPill
                        ? "The Rejsekort shortcut button is always visible on the main screen."
                        : "Show the Rejsekort shortcut button on the main screen when proximity or movement is detected.")
                }

                Section {
                    Toggle("Metro Proximity", isOn: $settings.proximityRejsekortAction)
                        .tint(.blue)
                    Toggle("Movement Detection", isOn: $settings.movementRejsekortAction)
                        .tint(.blue)
                } header: {
                    Text("Open Rejsekort on Notification Tap")
                } footer: {
                    Text("When enabled, tapping a notification opens the Rejsekort app instead of MetroSense.")
                }
            }
        }
        .navigationTitle("Rejsekort")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RejsekortSettingsView(settings: .constant(.default))
    }
}
