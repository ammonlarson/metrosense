import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendMetroDetected(line: String, fromStation: String) {
        let content = UNMutableNotificationContent()
        content.title = "Metro Detected"
        content.body = "You're on the \(line) from \(fromStation)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "metro-detected-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
