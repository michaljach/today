import UIKit
import UserNotifications

/// AppDelegate for handling push notifications and other system callbacks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    /// Stored device token for later use (e.g., unregistering on sign out)
    private(set) static var deviceToken: Data?
    
    // MARK: - App Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // MARK: - Remote Notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppDelegate.deviceToken = deviceToken
        
        Task {
            await PushNotificationService.shared.registerDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when a notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Called when user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Parse the notification and handle navigation
        if let payload = PushNotificationPayload(userInfo: userInfo) {
            handleNotificationTap(payload)
        }
        
        completionHandler()
    }
    
    // MARK: - Notification Handling
    
    private func handleNotificationTap(_ payload: PushNotificationPayload) {
        // Post notification for the app to handle navigation
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: [
                "type": payload.type.rawValue,
                "postId": payload.postId as Any,
                "actorId": payload.actorId as Any
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
    static let deviceTokenReceived = Notification.Name("deviceTokenReceived")
}
