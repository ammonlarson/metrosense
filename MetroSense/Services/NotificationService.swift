import UserNotifications
import Combine
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    static let proximityCategory = "PROXIMITY_NOTIFICATION"
    static let movementCategory = "MOVEMENT_NOTIFICATION"

    static let rejsekortAppURL = URL(string: "https://app.rejsekort.dk")!
    static let rejsekortStoreURL = URL(string: "https://apps.apple.com/app/id6469603787")!

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingRejsekortOpen: Bool = false

    private override init() {
        super.init()
    }

    func configure() {
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
        center.setNotificationCategories([proximityCategory, movementCategory])
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

    func sendMetroDetected(line: String, fromStation: String, tapAction: NotificationSettings.NotificationTapAction) {
        let content = UNMutableNotificationContent()
        content.title = "Metro Detected"
        content.body = "You're on the \(line) from \(fromStation)"
        content.sound = .default
        content.categoryIdentifier = Self.movementCategory
        content.userInfo = ["tapAction": tapAction.rawValue]

        let request = UNNotificationRequest(
            identifier: "metro-detected-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendProximityNotification(stationName: String, tapAction: NotificationSettings.NotificationTapAction) {
        let content = UNMutableNotificationContent()
        content.title = "Near Station"
        content.body = "You are near \(stationName)"
        content.sound = .default
        content.categoryIdentifier = Self.proximityCategory
        content.userInfo = ["tapAction": tapAction.rawValue]

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
        let userInfo = response.notification.request.content.userInfo
        let tapActionRaw = userInfo["tapAction"] as? String ?? ""
        let tapAction = NotificationSettings.NotificationTapAction(rawValue: tapActionRaw)

        if tapAction == .openRejsekort {
            Task { @MainActor in
                self.pendingRejsekortOpen = true
                completionHandler()
            }
        } else {
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
