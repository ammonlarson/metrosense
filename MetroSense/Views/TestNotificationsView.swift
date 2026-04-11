import CoreLocation
import SwiftUI

struct TestNotificationsView: View {
    @Binding var settings: NotificationSettings
    let location: CLLocation?
    let speed: Double?
    let lastMovementNotificationTime: Date?
    let lastProximityNotificationTime: Date?

    @State private var testResult: NotificationTestResult?
    @State private var isTesting: Bool = false
    @State private var testProgress: CGFloat = 0
    @State private var testRunId: Int = 0

    var body: some View {
        Form {
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
            } header: {
                Text("Settings")
            }

            rejsekortSection

            Section {
                Button {
                    runTest()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text("Test Notifications Now")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .disabled(!settings.isValid || isTesting)

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
                }
            } header: {
                Text("Check whether a notification would fire right now based on your current location and speed.")
            }

            if let result = testResult {
                Section("Results") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.proximityState.icon)
                            .foregroundStyle(result.proximityState.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.proximityState.label(for: "Proximity"))
                                .font(.body)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.movementState.icon)
                            .foregroundStyle(result.movementState.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.movementState.label(for: "Movement"))
                                .font(.body)
                            Text(result.movementDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, newValue in
            if newValue.isValid {
                newValue.save()
            }
        }
    }

    // MARK: - Rejsekort Section

    private var rejsekortSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Metro Proximity")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Picker("Tap opens", selection: $settings.proximityTapAction) {
                    Text("MetroSense").tag(NotificationSettings.NotificationTapAction.openMetroSense)
                    Text("Rejsekort").tag(NotificationSettings.NotificationTapAction.openRejsekort)
                }

                Toggle("Show Rejsekort button", isOn: $settings.proximityShowRejsekortPill)
                    .tint(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("On-Metro Traveling")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Picker("Tap opens", selection: $settings.movementTapAction) {
                    Text("MetroSense").tag(NotificationSettings.NotificationTapAction.openMetroSense)
                    Text("Rejsekort").tag(NotificationSettings.NotificationTapAction.openRejsekort)
                }

                Toggle("Show Rejsekort button", isOn: $settings.movementShowRejsekortPill)
                    .tint(.blue)
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rejsekort")
                Text("Choose what happens when you tap a notification and whether the Rejsekort shortcut button appears on the main screen.")
                    .textCase(nil)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
                location: location,
                speed: speed ?? 0,
                lastMovementNotificationTime: lastMovementNotificationTime,
                lastProximityNotificationTime: lastProximityNotificationTime
            )
            withAnimation {
                testResult = result
                isTesting = false
            }
        }
    }
}
