import CoreLocation
import SwiftUI

struct TestNotificationsView: View {
    @Binding var settings: NotificationSettings
    let location: CLLocation?
    let speed: Double?
    let lastMovementNotificationTime: Date?

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
                    Text("Minimum time between repeated movement alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Settings")
            }

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
                        Image(systemName: result.proximityWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.proximityWouldFire ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.proximityWouldFire ? "Proximity: Would fire" : "Proximity: Would not fire")
                                .font(.body)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.movementWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.movementWouldFire ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.movementWouldFire ? "Movement: Would fire" : "Movement: Would not fire")
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
                lastMovementNotificationTime: lastMovementNotificationTime
            )
            withAnimation {
                testResult = result
                isTesting = false
            }
        }
    }
}
