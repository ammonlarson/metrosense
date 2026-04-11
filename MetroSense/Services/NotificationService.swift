import UserNotifications
import Combine
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    static let proximityCategory = "PROXIMITY_NOTIFICATION"
    static let movementCategory = "MOVEMENT_NOTIFICATION"
    static let tunnelCategory = "TUNNEL_NOTIFICATION"

    static let rejsekortAppURL = URL(string: "https://app.rejsekort.dk")!
    static let rejsekortStoreURL = URL(string: "https://apps.apple.com/app/id6469603787")!

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingRejsekortOpen: Bool = false

    private var currentSettings: NotificationSettings = .default

    private override init() {
        super.init()
    }

    func configure(settings: NotificationSettings = .load()) {
        currentSettings = settings

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let proximityCategory = UNNotificationCategory(
            identifier: Self.proximityCategory,
            actions: [],
            intentIdentifiers: []
        )
        let movementCategory = UNNotificationCategory(
            identifier: Self.movementCategory,
            actions: [],
            intentIdentifiers: []
        )
        let tunnelCategory = UNNotificationCategory(
            identifier: Self.tunnelCategory,
            actions: [],
            intentIdentifiers: []
        )
        center.setNotificationCategories([proximityCategory, movementCategory, tunnelCategory])
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                if let error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
                self?.authorizationStatus = granted ? .authorized : .denied
            }
        }
    }

    func sendMetroDetected(line: String, fromStation: String) {
        let content = UNMutableNotificationContent()
        content.title = "Metro Detected"
        content.body = "You're on the \(line) from \(fromStation)"
        content.sound = .default
        content.categoryIdentifier = Self.movementCategory

        let request = UNNotificationRequest(
            identifier: "metro-detected-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendTunnelNotification(nearStation: String) {
        let content = UNMutableNotificationContent()
        content.title = "Possible Tunnel Travel"
        content.body = "You may be traveling underground near \(nearStation)"
        content.sound = .default
        content.categoryIdentifier = Self.tunnelCategory

        let request = UNNotificationRequest(
            identifier: "tunnel-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendProximityNotification(stationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Near Station"
        content.body = "You are near \(stationName)"
        content.sound = .default
        content.categoryIdentifier = Self.proximityCategory

        let request = UNNotificationRequest(
            identifier: "proximity-\(stationName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }

        let category = response.notification.request.content.categoryIdentifier

        Task { @MainActor in
            let settings = self.currentSettings
            let shouldOpenRejsekort = settings.rejsekortEnabled && (
                (category == Self.proximityCategory && settings.proximityRejsekortAction)
                || (category == Self.movementCategory && settings.movementRejsekortAction)
            )

            if shouldOpenRejsekort {
                self.pendingRejsekortOpen = true
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
