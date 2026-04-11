import SwiftUI
import UIKit

@main
struct MetroSenseApp: App {
    init() {
        NotificationService.shared.configure(settings: .load())
    }

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .onReceive(NotificationService.shared.$pendingRejsekortOpen) { shouldOpen in
                    guard shouldOpen else { return }
                    NotificationService.shared.pendingRejsekortOpen = false
                    UIApplication.shared.open(NotificationService.rejsekortAppURL) { accepted in
                        if !accepted {
                            Task { @MainActor in
                                UIApplication.shared.open(NotificationService.rejsekortStoreURL)
                            }
                        }
                    }
                }
        }
    }
}
